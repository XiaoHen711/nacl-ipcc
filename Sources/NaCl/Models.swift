import Foundation

/// 运营商配置（Carrier Bundle）。id 必须与
/// /System/Library/Carrier Bundles/iPhone 下的文件夹同名。
struct CarrierBundle: Identifiable, Hashable {
    let id: String
    let displayName: String

    static let presets: [CarrierBundle] = [
        .init(id: "CMCC_cn", displayName: "中国移动"),
        .init(id: "Unicom_cn", displayName: "中国联通"),
        .init(id: "Telecom_cn", displayName: "中国电信"),
        .init(id: "CBN_cn", displayName: "中国广电"),
    ]
}

/// 一次成功写入的回执。
struct LockReceipt: Equatable {
    let imsi: String
    let bundleID: String
    let date: Date
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
        "请求 AirTraffic 授权上下文",
        "读取 SIM 槽位与 IMSI",
        "校验 Bundle 名称与路径",
        "写入 Overlay 链接",
        "通知 CommCenter 重载配置",
        "校验生效状态",
    ]

    static let restoreSteps = [
        "移除 Overlay 登记",
        "重载 CommCenter 配置",
        "校验系统默认匹配",
    ]
}

enum NaClError: LocalizedError {
    case invalidIMSI
    case overlayWriteDenied
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidIMSI:
            return "IMSI 需要 6–15 位数字"
        case .overlayWriteDenied:
            return "AirTraffic 返回 0xE00002C1 · Operation not permitted（模拟）"
        case .cancelled:
            return "操作已取消"
        }
    }
}
