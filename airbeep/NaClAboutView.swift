import SwiftUI

struct NaClAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            NaClAboutContent()
                .navigationTitle("关于 NaCl IPCC")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
        }
    }
}

/// 说明页正文。sheet 与标签页共用，避免两份文案漂移。
struct NaClAboutContent: View {
    @State private var showingAdvanced = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [NaClTheme.deep, NaClTheme.deepDark],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 44
                                )
                            )
                            .frame(width: 84, height: 84)
                            .overlay {
                                Circle().strokeBorder(NaClTheme.accent, lineWidth: 1.5)
                            }
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(NaClTheme.mint)
                    }
                    Text("NaCl IPCC")
                        .font(.title2.bold())
                    Text(versionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("CARRIER LOCK")
                        .font(.caption2.weight(.semibold))
                        .tracking(2.6)
                        .foregroundStyle(NaClTheme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section("简介") {
                Text("卡贴机运营商配置锁定工具。把 Apple 已签名的运营商配置写进本机 iPhone 目录，让 CommCenter 优先选中指定运营商的 IPCC。")
                Text("支持系统：\(SystemCompatibility.supportedRangeDescription)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("原理") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("① 取用内置 Apple 已签名的 IPCC 外壳，仅整份替换 carrier.plist，signatures/ 与 *.der.pri 保持原样。")
                    Text("② 改写 bundle 身份并把 CFBundleVersion 提到 9999，让 CommCenter 优先选中。")
                    Text("③ 经 Airlift 的 AirTraffic 写入通道推进 /var/mobile/Library/Carrier Bundles/iPhone，随后注销重载。")
                }
                .font(.footnote)
            }

            Section("限制") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 不解除网络锁，也不绕过运营商激活策略。")
                    Text("• 抹除、还原、OTA、换 SIM 都会解掉，需要重写。")
                    Text("• CommCenter 若比对 version.plist 的 SourceVersion，可能回落到系统 bundle。")
                    Text("• 写入是否生效与系统版本强相关，请先用日志确认返回码。")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("高级") {
                Button {
                    showingAdvanced = true
                } label: {
                    Label("高级设置", systemImage: "slider.horizontal.3")
                }
                Text("自定义回环连接的设备 IP，并查看实时网络接口。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("运行日志") {
                ShareLink(item: AirBeepLog.shared.exportText()) {
                    Label("导出日志", systemImage: "square.and.arrow.up")
                }
                Button("清空日志", role: .destructive) {
                    AirBeepLog.shared.clear()
                }
            }

            Section("开源与许可") {
                Text("本工程以 GPL-3.0 发布；写入通道来自 airlift / AirCard-iOS，外壳与隧道封装来自 AirBeep。")
                    .font(.footnote)
                Text("无激活码、无 IMEI 绑定、无联网校验。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingAdvanced) {
            AirBeepAdvancedSettingsView()
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "版本 \(version) (\(build))"
    }
}

#Preview {
    NaClAboutView()
}
