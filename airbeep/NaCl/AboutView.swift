import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: LockStore

    var body: some View {
        ZStack {
            Theme.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("简介")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Chip(text: LockStore.versionText, mono: true)
                    }

                    AboutBlock(nil) {
                        paragraph("NaCl IPCC 把 Apple 已签名的运营商配置外壳写进本机的 Carrier Bundles 目录，让 CommCenter 优先命中这份配置，减少卡贴场景下的重复匹配与重新激活。")
                    }

                    AboutBlock("跳激活的原理") {
                        paragraph("卡贴会改写或伪造 SIM 上报的网络标识。CommCenter 在重启、基带复位或 SIM 重新注册之后，需要根据 IMSI/ICCID 重新挑选运营商配置；一旦匹配结果不稳定，就会走「需要重新激活」的流程。")
                        paragraph("夜间待机、长时间静置后重新唤醒时更容易出现：系统会进行维护任务，基带复位并重新读取卡信息，于是再次触发匹配。")
                    }

                    AboutBlock("锁定 IPCC 的目的") {
                        paragraph("把固定的运营商配置写进用户域的 Carrier Bundles 目录，并把版本号抬到 9999，使匹配结果稳定下来，减少日常使用、重启、基带复位后的配置漂移，也就减少了反复弹出的激活流程。")
                    }

                    AboutBlock("实现方式") {
                        VStack(alignment: .leading, spacing: 3) {
                            fact("外壳", "Apple 签名 IPCC（O2_Germany）")
                            fact("改动", "仅 carrier.plist + 身份/版本")
                            fact("通道", "Airlift · AirTraffic")
                            fact("校验", "写入后回读 Info.plist")
                        }
                        paragraphSmall("signatures/ 与 *.der.pri 保持原样，因此签名继续有效。")
                    }

                    AboutBlock("无法实现的功能") {
                        VStack(alignment: .leading, spacing: 2) {
                            bullet("不能解除网络锁，也不能绕过运营商侧的激活策略。")
                            bullet("不能阻止卡贴改动 IMSI，或阻止基带上报新值。")
                            bullet("不能保证换卡、换机、差旅漫游后仍然生效。")
                            bullet("不能修改系统分区，也不能在没有特权环境的情况下越权写文件。")
                            bullet("不能保证跨大版本系统升级或 AirTraffic 失效后继续可用。")
                        }
                    }

                    AboutBlock("参考") {
                        VStack(alignment: .leading, spacing: 3) {
                            fact("漏洞面", "AirTraffic / Airlift")
                            fact("写入库", "AirCard-iOS")
                            fact("隧道", "LocalDevVPN")
                            fact("配对", "iloader / pymobiledevice3")
                        }
                        paragraphSmall("以上仅作为公开思路来源标注；本项目为独立实现，界面与交互均为重写，不含其代码。")
                    }

                    AboutBlock("版本") {
                        VStack(alignment: .leading, spacing: 3) {
                            fact("应用", "NaCl IPCC \(LockStore.versionText)")
                            fact("最低系统", "iOS 16.0")
                            fact("可用范围", SystemCompatibility.supportedRangeDescription)
                            fact("构建", "SwiftUI · 未签名")
                        }
                    }

                    Text("仅供学习与自有设备调试，请遵守当地法律与运营商条款。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 文本片段

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.8))
            .foregroundStyle(Theme.text.opacity(0.78))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraphSmall(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.faint)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("✕")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(hex: 0x7A4A4A))
                .padding(.top, 4)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text.opacity(0.72))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private func fact(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.8))
        }
        .padding(.vertical, 2)
    }
}

private struct AboutBlock<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let heading = title {
                SectionTitle(text: heading)
            }
            content
        }
    }
}
