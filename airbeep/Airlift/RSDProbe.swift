import Foundation
import Network

/// 探测回环隧道里 RemotePairing（RSD）端口是否真的可连。
///
/// 不同 VPN 品牌给设备的地址不一样：LocalDevVPN 是 `10.7.0.1`，
/// SideStore WireGuard / StikDebug 常见 `172.16.0.1`。Rust 层有内置兜底地址，
/// 一旦我们自己设的目标不可达，它就会去试兜底地址，报错里出现的就是那个地址。
/// 所以先把能连的地址找出来，再定向设置。
@MainActor
enum RSDProbe {
    static let defaultPort: UInt16 = 49152

    static func canConnect(host: String, port: UInt16 = defaultPort, timeout: Double = 1.0) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let queue = DispatchQueue(label: "nacl.rsdprobe")
            var settled = false
            let settle: (Bool) -> Void = { reachable in
                if settled { return }
                settled = true
                connection.cancel()
                continuation.resume(returning: reachable)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    settle(true)
                case .failed, .cancelled:
                    settle(false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { settle(false) }
        }
    }

    static func firstReachable(in hosts: [String], port: UInt16 = defaultPort) async -> String? {
        for host in hosts where !host.isEmpty {
            if await canConnect(host: host, port: port) {
                return host
            }
        }
        return nil
    }
}
