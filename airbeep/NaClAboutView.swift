import SwiftUI

struct NaClAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdvanced = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 0.12, green: 0.29, blue: 0.20), Color(red: 0.05, green: 0.12, blue: 0.08)],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 44
                                    )
                                )
                                .frame(width: 84, height: 84)
                                .overlay {
                                    Circle().strokeBorder(Color(red: 0.24, green: 0.58, blue: 0.40), lineWidth: 1.5)
                                }
                            VStack(spacing: 1) {
                                Text("NaCl")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(red: 0.36, green: 0.90, blue: 0.62))
                                Text("IPCC")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(2.4)
                                    .foregroundStyle(Color(red: 0.29, green: 0.78, blue: 0.54))
                            }
                        }
                        Text("NaCl IPCC")
                            .font(.title2.bold())
                        Text(versionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }

                Section("简介") {
                    Text("卡贴机运营商配置锁定工具，氯化钠（NaCl）分支的 IPCC 产品。只保留「锁定 IPCC」能力，不含通话录音提示音功能。")
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
            .navigationTitle("关于 NaCl IPCC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAdvanced) {
                AirBeepAdvancedSettingsView()
            }
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
