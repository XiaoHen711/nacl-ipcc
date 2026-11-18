import Combine
import SwiftUI
import UIKit

@MainActor
final class IPCCViewModel: ObservableObject {
    static let shared = IPCCViewModel()

    @Published var selectedCarrierID: String = IPCCCarrierCatalog.all.first?.id ?? "46000"
    @Published private(set) var isBusy = false
    @Published private(set) var log: [String] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// 配对文件是否真的落在沙盒里。文件很小，直接查属性最可靠。
    @Published private(set) var pairingReady = false
    /// LocalDevVPN 之类的回环隧道是否已经起来（utun/ipsec 接口处于 up+running）。
    @Published private(set) var tunnelReady = false
    @Published private(set) var tunnelAddress: String?
    /// 「检测写入通道」的结果，nil 表示还没测过。
    @Published private(set) var channelMessage: String?
    @Published private(set) var isCheckingChannel = false

    private var pump: Task<Void, Never>?
    private var statusPump: Task<Void, Never>?

    var carriers: [IPCCCarrier] { IPCCCarrierCatalog.all }

    var selectedCarrier: IPCCCarrier {
        IPCCCarrierCatalog.carrier(for: selectedCarrierID) ?? IPCCCarrierCatalog.all[0]
    }

    // MARK: - 通道状态

    /// 主动刷新配对文件与隧道状态。返回、切回前台、下拉都会调用它，
    /// 避免页面上一直显示进入 App 那一刻的旧结果。
    func refreshStatus() {
        let path = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        pairingReady = FileManager.default.fileExists(atPath: path) && size > 0
        tunnelReady = NetworkStatus.loopbackTunnelActive
        tunnelAddress = NetworkStatus.tunnelInterfaceAddress
    }

    func startStatusPump() {
        guard statusPump == nil else { return }
        refreshStatus()
        statusPump = Task { @MainActor in
            while !Task.isCancelled {
                self.refreshStatus()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stopStatusPump() {
        statusPump?.cancel()
        statusPump = nil
    }

    /// 真刀真枪地跑一次管道查询，验证「配对 + 隧道」是否真的能通。
    func checkChannel() {
        guard !isBusy, !isCheckingChannel else { return }
        refreshStatus()
        isCheckingChannel = true
        channelMessage = nil
        Task {
            defer { isCheckingChannel = false }
            do {
                _ = try await TendiesEngine.shared.detectPosterBoardContainer(
                    pairingPath: PairingController.pairingFilePath()
                )
                channelMessage = "写入通道可用"
            } catch {
                channelMessage = "通道检测失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - 执行

    func run() {
        guard !isBusy else { return }
        refreshStatus()
        let pairing = PairingController.pairingFilePath()
        guard pairingReady else {
            errorMessage = "未找到可用的配对文件。请先在「配对设置」里完成配对或导入配对文件。"
            return
        }

        isBusy = true
        log.removeAll()
        AirBeepLog.shared.clear()
        startPump()
        let carrier = selectedCarrier

        Task {
            do {
                let staged = try await IPCCInstaller.shared.install(carrier: carrier, pairingPath: pairing)
                log.append("已写入 \(IPCCCarrierCatalog.deviceRoot)/\(carrier.bundleName)")
                try await IPCCInstaller.shared.respring(pairingPath: pairing)
                log.append("已发送重启指令")
                try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
                successMessage = "\(carrier.displayName) 配置已写入，设备即将重启。重启后到「设置 › 通用 › 关于本机 › 运营商」确认版本为 \(carrier.bundleName)。"
            } catch {
                errorMessage = error.localizedDescription
            }
            flushLog()
            stopPump()
            isBusy = false
            refreshStatus()
        }
    }

    private func startPump() {
        pump = Task { @MainActor in
            while !Task.isCancelled {
                self.flushLog()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    private func stopPump() {
        pump?.cancel()
        pump = nil
    }

    private func flushLog() {
        let lines = AirBeepLog.shared.drain()
        guard !lines.isEmpty else { return }
        log.append(contentsOf: lines)
        if log.count > 400 { log.removeFirst(log.count - 400) }
    }
}

/// 氯化钠分支的视觉基调：深绿底 + 薄荷绿高亮，沿用 AirBeep 的卡片式排版。
enum NaClTheme {
    static let deep = Color(red: 0.12, green: 0.29, blue: 0.20)
    static let deepDark = Color(red: 0.05, green: 0.12, blue: 0.08)
    static let accent = Color(red: 0.24, green: 0.62, blue: 0.44)
    static let mint = Color(red: 0.36, green: 0.90, blue: 0.62)
    static let card = Color(.secondarySystemGroupedBackground)
}

/// 主页面：hero 头部 + 状态 / 配置 / 执行 / 日志 四张卡片。
struct NaClLockView: View {
    @StateObject private var model = IPCCViewModel.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSetup = false
    @State private var showingAbout = false
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    if !SystemCompatibility.isSupported {
                        compatibilityCard
                    }
                    statusCard
                    carrierCard
                    actionCard
                    if !model.log.isEmpty {
                        logCard
                    }
                    notes
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("NaCl IPCC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("关于")
                }
            }
            .onAppear { model.startStatusPump() }
            .onDisappear { model.stopStatusPump() }
            .onChange(of: scenePhase, perform: handleScenePhase)
            .sheet(isPresented: $showingSetup, onDismiss: { model.refreshStatus() }) {
                AirBeepAirliftSetupView()
            }
            .sheet(isPresented: $showingAbout) { NaClAboutView() }
            .confirmationDialog("确认写入运营商配置？", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("执行锁定", role: .destructive) { model.run() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将覆盖 \(model.selectedCarrier.bundleName) 并重启设备。")
            }
            .alert("操作失败", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("好") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .alert("完成", isPresented: Binding(
                get: { model.successMessage != nil },
                set: { if !$0 { model.successMessage = nil } }
            )) {
                Button("好") { model.successMessage = nil }
            } message: {
                Text(model.successMessage ?? "")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NaClTheme.deep, NaClTheme.deepDark],
                            center: .center,
                            startRadius: 6,
                            endRadius: 52
                        )
                    )
                    .frame(width: 92, height: 92)
                    .overlay {
                        Circle().strokeBorder(NaClTheme.accent.opacity(0.9), lineWidth: 1.5)
                    }
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(NaClTheme.mint)
            }

            Text("NaCl IPCC")
                .font(.title2.bold())

            Text("CARRIER LOCK")
                .font(.footnote.weight(.semibold))
                .tracking(3)
                .foregroundStyle(NaClTheme.accent)

            Text("把 Apple 已签名的运营商配置写进本机 iPhone 目录，锁定指定运营商的 IPCC。不解除网络锁，也不改动激活策略。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(verbatim: versionLine)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active { model.refreshStatus() }
    }

    private var versionLine: String {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        let systemText = "\(platform) \(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
        return "\(systemText)  NaCl IPCC v\(appVersion)"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !version.isEmpty else { return build }
        guard !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    // MARK: - Cards

    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("系统版本不在支持范围")
                    .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            Text("当前系统的写入通道不可用，支持范围是 \(SystemCompatibility.supportedRangeDescription)。应用仍可安装，但执行锁定会失败。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            statusRow(
                systemImage: model.pairingReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: model.pairingReady ? .green : .orange,
                title: "配对文件",
                detail: model.pairingReady ? "已就绪" : "未找到"
            )

            Divider()

            statusRow(
                systemImage: model.tunnelReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: model.tunnelReady ? .green : .orange,
                title: "LocalDevVPN",
                detail: model.tunnelReady ? (model.tunnelAddress ?? "已连接") : "未连接"
            )

            Divider()

            statusRow(
                systemImage: channelIcon,
                tint: channelTint,
                title: "写入通道",
                detail: channelDetail
            )

            if let channelMessage = model.channelMessage {
                Text(channelMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    model.checkChannel()
                } label: {
                    HStack(spacing: 6) {
                        if model.isCheckingChannel {
                            ProgressView().controlSize(.small)
                        }
                        Text("检测通道")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.isCheckingChannel || model.isBusy)

                Button {
                    showingSetup = true
                } label: {
                    Label("配对设置", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(NaClTheme.accent)
            }
        }
        .padding(16)
        .background(NaClTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var channelIcon: String {
        if model.isCheckingChannel { return "arrow.triangle.2.circlepath" }
        if let message = model.channelMessage {
            return message.hasPrefix("写入通道可用") ? "checkmark.seal.fill" : "xmark.seal.fill"
        }
        return "questionmark.circle"
    }

    private var channelTint: Color {
        if model.isCheckingChannel { return .secondary }
        if let message = model.channelMessage {
            return message.hasPrefix("写入通道可用") ? .green : .red
        }
        return .secondary
    }

    private var channelDetail: String {
        if model.isCheckingChannel { return "检测中…" }
        if let message = model.channelMessage {
            return message.hasPrefix("写入通道可用") ? "可用" : "不可用"
        }
        return "未检测"
    }

    private func statusRow(systemImage: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var carrierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目标运营商", systemImage: "simcard.2")
                .font(.headline)

            Menu {
                ForEach(model.carriers) { carrier in
                    Button {
                        model.selectedCarrierID = carrier.id
                    } label: {
                        if carrier.id == model.selectedCarrierID {
                            Label("\(carrier.displayName) · \(carrier.id)", systemImage: "checkmark")
                        } else {
                            Text("\(carrier.displayName) · \(carrier.id)")
                        }
                    }
                }
            } label: {
                HStack {
                    Text(model.selectedCarrier.displayName)
                        .font(.body.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            detailRow("目标 Bundle", model.selectedCarrier.bundleName)
            detailRow("SupportedSIMs", model.selectedCarrier.supportedSIMs.joined(separator: " / "))
        }
        .padding(16)
        .background(NaClTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.trailing)
        }
    }

    private var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                showingConfirmation = true
            } label: {
                HStack {
                    if model.isBusy {
                        ProgressView()
                            .padding(.trailing, 6)
                        Text("正在写入…")
                            .font(.headline)
                    } else {
                        Label("执行锁定", systemImage: "lock.shield.fill")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(NaClTheme.accent)
            .disabled(model.isBusy || !model.pairingReady)

            Text("写入 /var/mobile/Library/Carrier Bundles/iPhone，随后发送重启指令。过程中请勿退出应用。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if !model.pairingReady {
                Text("按钮变灰是因为还没有可用的配对文件。点上面的「配对设置」导入或生成配对文件，回来会自动刷新。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(NaClTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("运行日志", systemImage: "text.alignleft")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(16)
        .background(NaClTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("使用内置的 Apple 签名外壳，只替换 carrier.plist，signatures 与 *.der.pri 保持原样。", systemImage: "signature")
            Label("抹除、还原、OTA 升级或更换 SIM 都会解掉，需要重新写入。", systemImage: "arrow.counterclockwise")
            Label("不解除网络锁，仅让运营商配置优先选中本机写入的 bundle。", systemImage: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NaClLockView()
}
