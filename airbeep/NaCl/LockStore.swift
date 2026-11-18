import SwiftUI

/// 单一状态源：界面只读这里，写入只走 `CarrierOverlayService`。
@MainActor
final class LockStore: ObservableObject {
    @Published var imsi = ""
    @Published var bundleID = CarrierBundle.presets[0].id
    @Published var phase: LockPhase = .idle
    @Published var logs: [LogEntry] = []
    @Published var channel: ChannelState = .unknown
    @Published var attemptedInvalidIMSI = false

    private let service: CarrierOverlayService
    private var task: Task<Void, Never>?
    private var monitor: Task<Void, Never>?

    private static let receiptKey = "nacl.lastLockReceipt"

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(service: CarrierOverlayService? = nil) {
        self.service = service ?? AirliftCarrierService()
        loadReceipt()
        append(.info, "NaCl IPCC \(Self.versionText) 启动")
        append(.info, "通道支持范围 \(SystemCompatibility.supportedRangeDescription)")
        refreshChannel()
        startMonitoring()
    }

    // MARK: - 派生状态

    var bundle: CarrierBundle {
        CarrierBundle.preset(forID: bundleID)
    }

    /// IMSI 只用于日志核对；留空也允许写入。
    var isValidIMSI: Bool {
        imsi.isEmpty || imsi.range(of: "^[0-9]{6,15}$", options: .regularExpression) != nil
    }

    var isBusy: Bool { phase.isBusy }

    var lockButtonTitle: String {
        if case .locked = phase { return "重新写入 Overlay" }
        return "锁定运营商配置"
    }

    var hintText: String {
        if attemptedInvalidIMSI && !isValidIMSI {
            return "IMSI 需要 6–15 位数字，或者留空。"
        }
        return "IMSI 可留空。填了只写进日志便于核对，不要填成卡贴卡自己的 IMSI。"
    }

    // MARK: - 动作

    func lock() {
        guard !isBusy else { return }
        guard isValidIMSI else {
            attemptedInvalidIMSI = true
            append(.error, "IMSI 格式不正确，已取消写入")
            return
        }

        task?.cancel()
        let carrier = bundle
        phase = .locking(step: 0)
        append(.info, "开始锁定 · \(carrier.id) · imsi=\(imsi.isEmpty ? "未填" : imsi)")

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let receipt = try await self.service.lock(
                    carrier: carrier.carrier,
                    imsi: self.imsi,
                    onStep: { [weak self] step in
                        guard let self else { return }
                        self.phase = .locking(step: step)
                        self.append(.info, LockFlow.steps[min(max(step, 0), LockFlow.steps.count - 1)])
                    }
                )
                self.phase = .locked(receipt)
                self.saveReceipt(receipt)
                self.append(.ok, receipt.verified
                             ? "写入成功 · \(receipt.bundleID) · 回读校验通过"
                             : "写入已提交 · \(receipt.bundleID) · 回读未确认")
            } catch is CancellationError {
                self.phase = .idle
                self.append(.warn, "写入被取消")
            } catch {
                self.phase = .failed(message: error.localizedDescription)
                self.append(.error, error.localizedDescription)
            }
            self.refreshChannel()
        }
    }

    func restore() {
        guard !isBusy else { return }
        if case .idle = phase { return }

        task?.cancel()
        let carrier = bundle
        phase = .restoring(step: 0)
        append(.warn, "开始恢复 · \(carrier.id)")

        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.restore(carrier: carrier.carrier) { [weak self] step in
                    guard let self else { return }
                    self.phase = .restoring(step: step)
                    self.append(.info, LockFlow.restoreSteps[min(max(step, 0), LockFlow.restoreSteps.count - 1)])
                }
                self.phase = .idle
                self.clearReceipt()
                self.append(.ok, "已写入停用标记，系统将回落到自带配置")
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(message: error.localizedDescription)
                self.append(.error, error.localizedDescription)
            }
            self.refreshChannel()
        }
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - 通道监测

    func refreshChannel() {
        let pairing = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairing)[.size] as? Int) ?? 0
        let pairingReady = FileManager.default.fileExists(atPath: pairing) && size > 0
        let tunnel = NetworkStatus.loopbackTunnelActive
        let address = NetworkStatus.tunnelInterfaceAddress
        let supported = SystemCompatibility.isSupported

        Task { [weak self] in
            guard let self else { return }
            let caps = await IPCCInstaller.shared.capabilitySummary()
            var problems: [String] = []
            if !pairingReady { problems.append("配对文件未就绪") }
            if !tunnel { problems.append("LocalDevVPN 未连接") }
            if caps.isEmpty { problems.append("缺少注入入口") }
            if !supported { problems.append("系统不在支持范围") }

            let next: ChannelState
            if problems.isEmpty {
                next = .ready("通道就绪 · \(address ?? "tunnel") · \(caps)")
            } else {
                next = .problem(problems.joined(separator: " · "))
            }
            if next != self.channel {
                self.channel = next
                if case .problem(let text) = next {
                    self.append(.warn, text)
                } else if case .ready(let text) = next {
                    self.append(.info, text)
                }
            }
        }
    }

    private func startMonitoring() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshChannel()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    // MARK: - 回执持久化

    private func saveReceipt(_ receipt: LockReceipt) {
        if let data = try? JSONEncoder().encode(receipt) {
            UserDefaults.standard.set(data, forKey: Self.receiptKey)
        }
    }

    private func loadReceipt() {
        guard let data = UserDefaults.standard.data(forKey: Self.receiptKey),
              let receipt = try? JSONDecoder().decode(LockReceipt.self, from: data) else { return }
        phase = .locked(receipt)
    }

    private func clearReceipt() {
        UserDefaults.standard.removeObject(forKey: Self.receiptKey)
    }

    // MARK: - 日志

    func append(_ level: LogEntry.Level, _ text: String) {
        logs.append(LogEntry(time: Date(), level: level, text: text))
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
        AirBeepLog.shared.append(text)
    }

    var exportText: String {
        let header = "NaCl IPCC 运行日志\n"
        let body = logs.map {
            "[\(Self.clock.string(from: $0.time))] \($0.level.rawValue.uppercased()) \($0.text)"
        }.joined(separator: "\n")
        return header + body + "\n"
    }

    static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
