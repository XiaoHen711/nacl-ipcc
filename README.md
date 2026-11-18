# 氯化钠 · NaCl

卡贴机 / IPCC 锁定工具的工程骨架。名字取自氯化钠（盐），界面按 `CarrierLock` 的信息结构重写：薄荷绿、底部三页签、NaCl 圆形字标，没有沿用原图的青色与天线图标。

> **当前状态**：UI 与工程已完成，**还没编译过**——这台 Windows 上没有 iOS 工具链，本地尝试 xtool 交叉编译时被它自带的 ICU 依赖卡住（详见第五节）。出包走 GitHub Actions / Mac 均可，本仓库已带好流水线。

---

## 一、能做什么 / 不能做什么

**能**

- 完整 SwiftUI App（iOS 16+）：锁定页、日志页、关于页，含写入状态机、进度条、失败分支、日志导出
- Windows 上立刻可看的 HTML 原型：`prototype/index.html`（双击即可，不需要任何工具链）
- GitHub Actions 一键出**未签名 IPA**（TrollStore 直装，或用爱思助手签名）

**不能**

- 不含 AirTraffic 的真实写入实现。`CarrierOverlayService` 目前只有 `MockCarrierOverlayService`；真实写入需要 root 进程 + AirTraffic 私有框架 + 写 Overlay 目录，属特权代码，边界见 `Sources/NaCl/LockService.swift`

---

## 二、目录

```
.
├─ Sources/NaCl/            SwiftUI 源码（SwiftPM / Xcode 共用）
│  ├─ NaClApp.swift         入口
│  ├─ RootView.swift        TabView 三页签
│  ├─ Theme.swift           颜色令牌
│  ├─ Components.swift      卡片、按钮、Chip、进度条
│  ├─ Models.swift          CarrierBundle / LockPhase / LockFlow
│  ├─ LockService.swift     ★ 写入层抽象 + Mock 实现
│  ├─ LockStore.swift       状态机（唯一状态源）
│  ├─ LockView.swift        锁定页 + 状态卡
│  ├─ LogsView.swift        日志页
│  └─ AboutView.swift       关于页
├─ Package.swift            SwiftPM（给 xtool 用）
├─ xtool.yml                xtool 配置（bundleID）
├─ project.yml              XcodeGen 配置（Xcode / CI 用）
├─ prototype/index.html     可直接打开的界面原型（支持 #locked / #failed / #logs / #about）
├─ scripts/build-ipa-macos.sh
└─ .github/workflows/build-ipa.yml
```

---

## 三、出包

### 路线 A：GitHub Actions（推荐，不需要 Mac / Apple ID）

1. 把本仓库推到 GitHub（默认分支 `main`）
2. Actions → `build-ipa` → Run workflow
3. 等约 3–5 分钟，下载 artifact `NaCl-unsigned-ipa`，里面是 `NaCl-unsigned.ipa`

```bash
git init
git add .
git commit -m "nacl: initial"
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git push -u origin main
```

流水线做的事：`brew install xcodegen` → `xcodegen generate` → `xcodebuild`（`CODE_SIGNING_ALLOWED=NO`）→ 打包 `Payload/` 成 ipa → 上传 artifact，并附 SHA-256。

免费额度：公开仓库不限；私有仓库每月 2000 分钟，macOS 按 10 倍折算 = 200 分钟，一次构建约 3–5 分钟。

### 路线 B：有 Mac

```bash
brew install xcodegen
bash scripts/build-ipa-macos.sh
# 产物 dist/NaCl-unsigned.ipa
```

### 路线 C：本机 Linux/WSL + xtool（当前受阻）

E 盘上的 WSL 发行版 `nacl` 里已经装好 Swift 6.4.2 与 xtool 1.24.0，`Xcode_27.2.xip` 也已解出 `Xcode.app`（含 232 MB 的 iPhoneOS.sdk）。

但 xtool 1.24 / 1.23 在本机执行 `sdk install` 时会 `SIGILL`。已用 `strace` 定位：崩溃前最后一步是查找 `/usr/share/icu/icudt76l/uts46.nrm`——它自带的 Foundation 需要 **ICU 76 的文件式数据目录**，而 Ubuntu 24.04 只有 ICU 74（数据编译在 .so 里），因此任何涉及 URL 的子命令都会 trap。这是 xtool Linux 包的环境依赖问题，与本仓库代码无关。

补齐 ICU 76 数据目录后，路线 C 应该就能跑通：`xtool sdk install <Xcode.app>` → `xtool dev build -c release --ipa`。

---

## 四、签名与安装

- **TrollStore**：直接装未签名 `NaCl-unsigned.ipa`，免签名，最省事（卡贴机环境常用）
- **爱思助手**：工具箱 → IPA 签名 → 选 ipa → 用你的 Apple ID 签 → 安装

签名后的 app 若要真的写 Overlay，还需要 root 权限（TrollStore 的 `platform-application` 或越狱环境）。普通个人证书只能跑界面。

---

## 五、接上真实写入

`Sources/NaCl/LockService.swift` 里的 `CarrierOverlayService` 是边界，真机实现至少要满足：

1. 进程以 root 运行（TrollStore 持久化签名 / 越狱 daemon）
2. 能连 `airtrafficd`（AirTraffic 私有框架或其 XPC 接口）
3. 能写 `/System/Library/Carrier Bundles/iPhone/Overlay` 下的登记项，并让 CommCenter 重载

替换方式：实现一个 `AirTrafficOverlayService: CarrierOverlayService`，在 `LockStore.init(service:)` 注入即可，UI 与状态机不用改。

写入前务必确认 IMSI 是本机 SIM 的 IMSI——写错运营商配置会匹配到错误目标，表现为信号不稳、功能异常或反复激活（确认弹窗就是为此保留的）。

---

## 六、免责

仅供学习与自有设备调试。绕过运营商配置匹配、解锁网络锁可能违反运营商条款或当地法律，风险自负。
