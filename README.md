# NaCl IPCC

> 卡贴机的运营商配置（IPCC）锁定工具。GPL-3.0 开源，无激活码、无 IMEI 绑定、无联网校验。

NaCl IPCC 把 Apple 已签名的运营商配置外壳写进本机的 `Carrier Bundles/iPhone` 目录，让 CommCenter
优先选中你指定的运营商 bundle。它不解除网络锁，也不改运营商激活策略，只负责「让本机用哪份 IPCC」。

## 功能

- 选运营商 → 写入 → 注销重载，三步完成，主页单页操作。
- 只替换 `carrier.plist`，保留模板里的 `signatures/` 与 `*.der.pri`，因此 Apple 的签名继续有效。
- bundle 身份改写 + `CFBundleVersion` 提到 `9999`，压过系统自带 bundle。
- 主页实时显示 **配对文件 / LocalDevVPN / 写入通道** 三项状态，可一键「检测通道」验证是否真能通。
- 运行日志实时滚动，失败原因直接给到原文，不会只丢一句「失败」。

## 原理

1. 内置 Apple 签名的 `O2_Germany.ipcc` 作为外壳，解包后整份替换 `carrier.plist`。
2. 改写 `Info.plist` / `version.plist` 的 bundle 身份与版本号。
3. 通过 Airlift 的 AirTraffic 写入通道（`al_exploit_write_dir`）把整个目录推进
   `/var/mobile/Library/Carrier Bundles/iPhone/`，随后 `al_device_respring` 注销重载。

详见 [docs/PRINCIPLE.md](docs/PRINCIPLE.md)。

## 运行要求

- 真机 iPhone / iPad，功能可用范围：**iOS / iPadOS 18.0 – 27.2 B2**。
  安装门槛已降到 iOS 16.0：低于 18.0 的设备可以装，但主页会提示写入通道不可用。
- 需要 **配对文件** + **LocalDevVPN 回环隧道**（10.7.0.1）。iOS 27 起可在 App 内直接配对，
  更低版本需要在电脑上用 iloader 生成配对文件后导入。
- 签名需自己完成：用爱思 / Sideloadly 对 unsigned IPA 签名安装，或自备开发者证书。

## 构建

- 本地：打开 `airbeep.xcodeproj`，选 `airbeep` target，配好签名后真机构建。
- 云端：GitHub Actions 的 `Release unsigned IPA` 工作流构建未签名 IPA（产物名 `airipcc-lite-v<version>-unsigned.ipa`）。

连接目标默认 `10.7.0.1`（LocalDevVPN 的设备 IP）；可用 `AIRLIFT_TARGET_HOST` 覆盖。

## 开源组件

- [airlift](https://github.com/0xjohnnydev/airlift)：AirTraffic / Airlock 通道研究。
- AirBeep：外壳、隧道封装与界面骨架（本项目由其派生）。
- [AirliftSilence](https://github.com/YiHoooong/AirliftSilence)：早期提示音替换研究。
- [Placard](https://github.com/frs0n/placard)：容器访问实现与工程结构参考。

## 许可

GPL-3.0，见 [LICENSE](LICENSE)。仓库内的运营商配置数据来自 Apple 官方 IPCC，仅作研究与自用。
