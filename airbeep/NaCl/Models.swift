import Foundation

/// 一个可选的运营商配置。`id` 是 Overlay 目录名（去掉 `.bundle`），
/// 与 `IPCCCarrierCatalog` 的条目一一对应。
struct CarrierBundle: Identifiable, Hashable {
    let id: String
    let displayName: String
    let carrier: IPCCCarrier

    static let presets: [CarrierBundle] = IPCCCarrierCatalog.all.map {
        CarrierBundle(id: $0.shortName, displayName: $0.displayName, carrier: $0)
    }

    static func preset(forID id: String) -> CarrierBundle {
        presets.first { $0.id == id } ?? presets[0]
    }
}

/// 一次成功写入的回执。`verified` 表示写完之后回读 `Info.plist` 校验通过。
struct LockReceipt: Equatable, Codable {
    let bundleID: String
    let imsi: String
    let date: Date
    let verified: Bool
}

enum LockPhase: Equatable {
    case idle
    case locking(step: Int)
    case locked(LockReceipt)
    case restoring(step: Int)
    case failed(message: String)

    var isBusy: Bool {
        switch self {
        case .locking, .restoring: return true
        default: return false
        }
    }
}

/// 通道健康度，只影响顶部那条提示，不阻塞操作。
enum ChannelState: Equatable {
    case unknown
    case ready(String)
    case problem(String)
}

struct LogEntry: Identifiable, Equatable {
    enum Level: String {
        case info, ok, warn, error
    }

    let id = UUID()
    let time: Date
    let level: Level
    let text: String
}

enum LockFlow {
    static let steps = [
        "检查配对文件与 LocalDevVPN",
        "打包 Apple 签名 IPCC 外壳",
        "写入 Carrier Bundles/iPhone",
        "回读校验写入结果",
        "注销并重载 CommCenter",
        "记录锁定状态",
    ]

    static let restoreSteps = [
        "写入停用标记（版本号归零）",
        "注销并重载 CommCenter",
        "清理本地记录",
    ]
}

enum NaClError: LocalizedError {
    case missingPairingFile
    case tunnelDown
    case invalidIMSI
    case timeout
    case cancelled
    case ipccFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPairingFile:
            return "没有可用的配对文件。先在配对设置里导入或生成配对文件。"
        case .tunnelDown:
            return "LocalDevVPN 没有连接。连上 10.7.0.1 的回环隧道后重试。"
        case .invalidIMSI:
            return "IMSI 需要 6–15 位数字，或者留空。"
        case .timeout:
            return "等待设备响应超时（AirTraffic 未返回）。"
        case .cancelled:
            return "操作已取消。"
        case .ipccFailed(let message):
            return message
        }
    }
}
