# 氯化钠 · 原理与开源组件地图

本文说明这套工具**为什么能在不越狱的情况下写入运营商配置**，以及整条链路上每个开源组件负责哪一段。
本项目不做授权码、不做 IMEI 绑定、不联网校验——商业版收的钱是授权与售后，不是技术。

---

## 0. 目标与边界

| 做什么 | 不做什么 |
|---|---|
| 把一份“已由 Apple 签名”的 Carrier Bundle 复刻成目标运营商的配置 | 不写系统分区（`/System`） |
| 用 AirTraffic 的同步通道把它放进 `/var/mobile/Library/Carrier Bundles/iPhone/` | 不解锁网络锁、不绕过运营商激活策略 |
| 注销（respring）让 CommCenter 重新加载 | 不获得 root、不注入进程 |

写的是**用户目录**，所以不需要 root；生效靠“让 CommCenter 优先选中这份配置”。

---

## 1. 漏洞层：AirTraffic / ATAirlock 的路径穿越

AirTraffic 是 iOS 上负责“从电脑同步媒体（含 Books）”的服务。它按“资产（asset）”处理书目：

- `Persistent ID` → 源路径
- `FileComplete.AssetPath` → 目标路径

`-[ATAirlock processCompletedAsset:]` 的核心逻辑可简化为：

```objc
source = "/var/mobile/Media/Airlock/Book/" + asset.identifier;   // 可含 ..
destination = ["/var/mobile/Media/" stringByAppendingPathComponent:asset.path]
              .stringByStandardizingPath;

if (![destination hasPrefix:@"/var/mobile/Media/"]) return;       // 只查字符串
[fileManager moveItemAtPath:source toPath:destination error:&e];
```

两个缺口叠加：

1. **source 可含 `..`** —— 源路径不受约束；
2. **destination 的前缀检查只看字符串**，不看符号链接最终指向 —— 目标可以是“位于 Media 内、但实际指向外部”的链接。

利用方式是三次搬运：

```
① 把“相对符号链接”作为 Book 资产搬进 Media
   → 链接在 Media 里的相对位置解析到 /var/tmp
② 第二次搬运经过该链接 → 文件实际落在 /var/tmp（或其它可达目录）
③ 第三次把它搬回 Media，再由 AFC 读回校验字节
```

`0xjohnnydev/airlift` 用这个方式在 iOS 27.0 RC 上确认了以下目录可写**新文件**：
`/var/mobile`、`/var/mobile/Documents`、`/var/mobile/Library`、`.../Library/{Preferences,Caches,SpringBoard,SMS,Safari}`、
`/var/mobile/Containers*`、`/var/tmp`。

> 注意：这证明的是“新文件”，不是“覆盖已有文件”，也不是内核提权。

---

## 2. 传输层：Airlift FFI

`AirCard-iOS`（Rust）把上面的 ATC 消息拼装封装成 C ABI，供 Swift 调用。目前稳定导出的只有 4 个：

```c
int32_t al_exploit_write_dir (const char *pairing, const char *src, const char *dst, ...);
int32_t al_exploit_read_file (const char *pairing, const char *path, ...);
int32_t al_find_app_container(const char *pairing, const char *bundleID, ...);
int32_t al_device_respring  (const char *pairing, ...);
```

`inject_folder` / `clear_dir` / `write_symlinks` 在头文件里有声明，但对应 commit 的 `.a` 里没有符号，调用会 `dlsym` 失败。

**因此本项目用“两次 `write_dir`”代替 `inject_folder`**：

1. 先把 bundle 根目录的**平铺文件**写进目标目录；
2. 再写 `signatures/` 子目录。

这也意味着一个未验证假设：`write_dir` 会创建不存在的目标目录。若首次报“目标 …/CMCC_cn.bundle”，就是它不会建，需要换带 `inject_folder` 的 Airlift 版本。

---

## 3. 隧道与配对层

App 要访问的是**设备自己的** Lockdown 回环端口，而沙盒不允许直接连。整条链需要：

| 组件 | 作用 | 开源 |
|---|---|---|
| `iloader` | 电脑端生成 rppairing / lockdown 配对文件并导入 | ✅ |
| `LocalDevVPN` | 在手机上建一条本地隧道，让 App 能连到设备回环（默认目标 `10.7.0.1`） | ✅（SideStore 生态） |
| iOS 27+ | 支持在「设置 › 隐私与安全性 › 开发者模式」里直接与本机 App 配对，无需配对文件 | 系统能力 |

iOS 26.4 起，旧式 Lockdown 回环连接还受**实际 Wi-Fi 网段**约束：隧道地址要按当前网络配置，换网段要重配。

---

## 4. 应用层：IPCC 重打包

这份实现不改系统签名，做法是“**复用一份已签名的模板，只动签名没覆盖的部分**”。

模板：`O2_Germany.ipcc`（Apple 签名的真实运营商 bundle）。
签名只覆盖 `*.der.pri` 与 `signatures/`，**不覆盖 `carrier.plist`**。

所以：

1. 解包模板；
2. 整份替换 `carrier.plist`（换成 46000/46001/46011/46015 等）；
3. 改写身份：`CFBundleIdentifier` → `com.apple.Carrier_CMCC_cn`，`CFBundleName/Executable` → `CMCC_cn`；
4. 把 `CFBundleVersion` 抬到 `9999`（`version.plist` 同步改），让 CommCenter 优先选这份而不是系统自带；
5. 两次 `al_exploit_write_dir` 推到 `/var/mobile/Library/Carrier Bundles/iPhone/CMCC_cn.bundle`；
6. `al_device_respring` 注销。

重启后：设置 › 通用 › 关于本机 › 运营商，版本应变成 `9999`。

---

## 5. 开源组件清单

| 组件 | 许可 | 用途 |
|---|---|---|
| [0xjohnnydev/airlift](https://github.com/0xjohnnydev/airlift) | MIT | 漏洞研究 PoC（路径穿越原理） |
| AirCard-iOS（`mak5er`，commit `40640c4`） | 见上游 | AirliftFFI：ATC 消息拼装 + FFI |
| [LinkPass888/AirBeep](https://github.com/LinkPass888/AirBeep) | GPL-3.0 | 本项目基线（提示音 + 隧道/配对封装） |
| [nab138/iloader](https://github.com/nab138/iloader) | 见上游 | 配对文件生成（Windows/macOS/Linux） |
| LocalDevVPN | 见上游 | 本地隧道（NetworkExtension） |
| **本项目** | GPL-3.0 | IPCC 重打包、锁定流程、界面与状态机 |

商用 AirIPCC 与这套的差别只有三点：**IMEI 绑定激活码**、**限定 iOS 27.0–27.0.1**、**只承诺 QPE 模式卡贴**。前两点是商业控制与风险规避，不是技术门槛。

---

## 6. 已知限制（务必先看）

1. `write_dir` 是否自动建目录**未验证**（见第 2 节）。
2. `bundleName` / `bundleIdentifier` 的映射是公开命名惯例，不同 iOS 可能不同。
3. `CFBundleVersion = 9999` 不一定够：若 CommCenter 还比较 `version.plist` 的 `SourceVersion`，可能回落到系统 bundle。
4. iOS 27.x 存在“写入返回成功但实际未生效”的报告（AirBeep issue #6）。
5. 抹除、还原、OTA 升级、换 SIM 都会解除，需要重新写。
6. 模板与 `460xx.plist` 来自公开分发的安装包，版权归 Apple 与相应运营商；仅作技术验证，不要商用分发。

---

## 7. 复现步骤

```bash
# 1. 构建（GitHub Actions 或本地 Xcode 27+）
bash scripts/build-airlift-xcframework.sh          # 可选：重建 AirliftFFI
xcodebuild archive -project airbeep.xcodeproj -scheme airbeep \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath /tmp/nacl.xcarchive \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 2. 打包未签名 IPA
mkdir -p /tmp/Payload && cp -R /tmp/nacl.xcarchive/Products/Applications/airbeep.app /tmp/Payload/
(cd /tmp && zip -qry NaCl-unsigned.ipa Payload)
```

手机上：

1. 用 iloader 导入配对文件（iOS 27+ 可跳过，直接在设置里配对）；
2. 安装并连上 LocalDevVPN（默认 `10.7.0.1`）；
3. 打开氯化钠 → 选运营商 → 锁定 → 注销后到「关于本机」核对运营商版本。
