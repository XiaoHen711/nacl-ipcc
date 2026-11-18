import SwiftUI

/// 单一状态源：界面只读这里，写入只走 `CarrierOverlayService`。
@MainActor
final class LockStore: ObservableObject {
    @Published var imsi = ""
    @Published var bundleID = CarrierBundle.presets[0].id
    @Published var phase: LockPhase = .idle
    @Published var logs: [LogEntry] = []
    @Published var autoLock = true
    @Published var demoFailure = false
    @Published var attemptedInvalidIMSI = false

    private let service: CarrierOverlayService
    private var task: Task<Void, Never>?

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(service: CarrierOverlayService? = nil) {
        self.service = service ?? MockCarrierOverlayService()
        append(.info, "airtrafficd 未连接（演示模式）")
        append(.info, "已加载 \(CarrierBundle.presets.count) 个运营商配置")
    }

    // MARK: - 派生状态

    var bundle: CarrierBundle {
        CarrierBundle.presets.first { $0.id == bundleID } ?? CarrierBundle.presets[0]
    }

    var isValidIMSI: Bool {
        imsi.range(of: "^[0-9]{6,15}$", options: .regularExpression) != nil
    }

    var isBusy: Bool { phase.isBusy }

    var lockButtonTitle: String {
        if case .locked = phase { return "重新写入 Overlay" }
        return "锁定运营商配置"
    }

    var hintText: String {
        if attemptedInvalidIMSI && !isValidIMSI {
            return "IMSI 需要 6–15 位数字，通常是 15 位。"
        }
        return "IMSI 会在开始监听并刷新 SIM 信号后自动填入，也可以手动输入。"
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
        if let mock = service as? MockCarrierOverlayService {
            mock.failureStep = demoFailure ? 3 : nil
        }

        phase = .locking(step: 0)
        append(.info, "开始锁定流程 · bundle=\(bundleID) · imsi=\(imsi)")

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let receipt = try await self.service.lock(
                    imsi: self.imsi,
                    bundleID: self.bundleID,
                    onStep: { [weak self] step in
                        guard let self else { return }
                        self.phase = .locking(step: step)
                        self.append(.info, LockFlow.steps[step])
                    }
                )
                self.phase = .locked(receipt)
                self.append(.ok, "Overlay 已生效 · \(receipt.bundleID) → \(receipt.imsi)")
            } catch is CancellationError {
                self.phase = .idle
                self.append(.warn, "写入被取消")
            } catch {
                self.phase = .failed(message: error.localizedDescription)
                self.append(.error, error.localizedDescription)
            }
        }
    }

    func restore() {
        guard !isBusy else { return }
        if case .idle = phase { return }

        task?.cancel()
        phase = .restoring(step: 0)
        append(.warn, "开始恢复 · 移除 Overlay 登记")

        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.restore(onStep: { [weak self] step in
                    guard let self else { return }
                    self.phase = .restoring(step: step)
                    self.append(.info, LockFlow.restoreSteps[step])
                })
                self.phase = .idle
                self.append(.ok, "已恢复系统默认运营商配置")
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(message: error.localizedDescription)
                self.append(.error, error.localizedDescription)
            }
        }
    }

    /// 演示用：模拟从 SIM 读到 IMSI。
    func requestIMSI() {
        guard imsi.isEmpty else { return }
        imsi = "460003403304039"
        append(.info, "已从 SIM 读取 IMSI（演示数据）")
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - 日志

    func append(_ level: LogEntry.Level, _ text: String) {
        logs.append(LogEntry(time: Date(), level: level, text: text))
    }

    var exportText: String {
        let header = "氯化钠 NaCl 运行日志\n"
        let body = logs.map {
            "[\(Self.clock.string(from: $0.time))] \($0.level.rawValue.uppercased()) \($0.text)"
        }.joined(separator: "\n")
        return header + body + "\n"
    }
}
