import Foundation

/// 写入层的抽象：界面只跟它打交道，真实实现走 Airlift 通道。
@MainActor
protocol CarrierOverlayService {
    func lock(carrier: IPCCCarrier,
              imsi: String,
              onStep: @MainActor (Int) -> Void) async throws -> LockReceipt
    func restore(carrier: IPCCCarrier, onStep: @MainActor (Int) -> Void) async throws
}

/// 真实实现：打包 → 写入 → 回读校验 → 注销。
@MainActor
final class AirliftCarrierService: CarrierOverlayService {
    func lock(carrier: IPCCCarrier,
              imsi: String,
              onStep: @MainActor (Int) -> Void) async throws -> LockReceipt {
        onStep(0)
        // 先把真正可连的 RSD 地址探出来，避免 Rust 层回落到内置的 172.16.0.1。
        _ = await NetworkStatus.selectReachableTarget(force: true)
        let pairing = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairing)[.size] as? Int) ?? 0
        guard FileManager.default.fileExists(atPath: pairing), size > 0 else {
            throw NaClError.missingPairingFile
        }
        guard NetworkStatus.loopbackTunnelActive else {
            throw NaClError.tunnelDown
        }

        onStep(1)
        let staged = try await IPCCInstaller.shared.stage(carrier: carrier)

        onStep(2)
        do {
            try await IPCCInstaller.shared.write(staged: staged, carrier: carrier, pairingPath: pairing)
        } catch {
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            throw error
        }

        onStep(3)
        let verified = await Self.verify(carrier: carrier, pairingPath: pairing)

        onStep(4)
        try await IPCCInstaller.shared.respring(pairingPath: pairing)

        onStep(5)
        try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
        return LockReceipt(bundleID: carrier.shortName, imsi: imsi, date: Date(), verified: verified)
    }

    func restore(carrier: IPCCCarrier, onStep: @MainActor (Int) -> Void) async throws {
        let pairing = PairingController.pairingFilePath()
        onStep(0)
        let staged = try await IPCCInstaller.shared.stageDisabled(carrier: carrier)
        do {
            try await IPCCInstaller.shared.write(staged: staged, carrier: carrier, pairingPath: pairing)
        } catch {
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            throw error
        }
        try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())

        onStep(1)
        try await IPCCInstaller.shared.respring(pairingPath: pairing)

        onStep(2)
    }

    /// 回读设备上的 `Info.plist`，确认 `CFBundleVersion` 已经是 9999。
    /// 读取通道在部分系统版本上不响应，所以带超时，失败只算「未校验」。
    private static func verify(carrier: IPCCCarrier, pairingPath: String) async -> Bool {
        let path = "\(IPCCCarrierCatalog.deviceRoot)/\(carrier.bundleName)/Info.plist"
        do {
            let data = try await withTimeout(seconds: 12) {
                try await IPCCInstaller.shared.readDeviceFile(path, pairingPath: pairingPath)
            }
            guard let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let plist = object as? [String: Any] else { return false }
            return (plist["CFBundleVersion"] as? String) == "9999"
        } catch {
            AirBeepLog.shared.append("回读校验未完成：\(error.localizedDescription)")
            return false
        }
    }
}

/// 把任何可能永久挂住的调用包一层超时。
func withTimeout<T: Sendable>(seconds: Double,
                              _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NaClError.timeout
        }
        guard let result = try await group.next() else { throw NaClError.timeout }
        group.cancelAll()
        return result
    }
}
