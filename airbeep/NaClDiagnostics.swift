import Foundation
import UIKit

/// 启动时就写进日志的环境快照，让导出的日志能自证"当时是什么状态"，
/// 不用再靠肉眼猜配对文件/隧道到底在不在。
enum NaClDiagnostics {
    static func logStartup() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        AirBeepLog.shared.append("app: NaCl IPCC \(version) (\(build)) · \(platform) \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) · \(UIDevice.current.model)")

        AirBeepLog.shared.append("支持范围 \(SystemCompatibility.supportedRangeDescription) · supported=\(SystemCompatibility.isSupported) · 自配对=\(SystemCompatibility.supportsOnDevicePairing)")

        let pairing = PairingController.pairingFilePath()
        let size = (try? FileManager.default.attributesOfItem(atPath: pairing)[.size] as? Int) ?? 0
        AirBeepLog.shared.append("配对文件: \(pairing) exists=\(FileManager.default.fileExists(atPath: pairing)) size=\(size)B")

        let tunnelAddress = NetworkStatus.tunnelInterfaceAddress ?? "none"
        AirBeepLog.shared.append("LocalDevVPN: up=\(NetworkStatus.loopbackTunnelActive) addr=\(tunnelAddress) target=\(TargetHostConfig.effective)")

        Task {
            let caps = await IPCCInstaller.shared.capabilitySummary()
            AirBeepLog.shared.append("airlift 入口: \(caps.isEmpty ? "缺失" : caps)")
        }
    }
}
