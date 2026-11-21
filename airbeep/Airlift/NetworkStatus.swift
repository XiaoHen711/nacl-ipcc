import AirliftFFI
import Darwin
import Foundation

/// Local interface enumeration via `getifaddrs`.
///
/// Everything here is read from the interface table only — deterministic and
/// offline, with no route probes or test connections.
enum NetworkStatus {
    struct Interface {
        let name: String
        let ipv4: String
        let isUp: Bool
        let isRunning: Bool
    }

    /// All IPv4 interfaces, in system order.
    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            guard let ipv4 = numericHost(addr) else { continue }
            let flags = current.pointee.ifa_flags
            result.append(
                Interface(
                    name: String(cString: current.pointee.ifa_name),
                    ipv4: ipv4,
                    isUp: flags & UInt32(IFF_UP) != 0,
                    isRunning: flags & UInt32(IFF_RUNNING) != 0
                )
            )
        }
        return result
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(addr, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
            return nil
        }
        return String(cString: host)
    }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    /// Wi-Fi is carrying traffic. `en0` is Wi-Fi on both iPhone and iPad
    /// (cellular shows up as `pdp_ip*`). The interface flags matter more than
    /// mere presence, since a stale `en0` entry can linger after Wi-Fi drops.
    static var wifiActive: Bool {
        interfaces().contains { $0.name == "en0" && $0.isUp && $0.isRunning }
    }

    /// A loopback VPN tunnel is up (LocalDevVPN, SideStore WireGuard, …).
    static var loopbackTunnelActive: Bool {
        interfaces().contains { isTunnelInterface($0.name) && $0.isUp && $0.isRunning }
    }

    /// The tunnel's own address, for the runtime log and setup screen. This
    /// is *not* a dial target — in a loopback VPN the device RSD endpoint is
    /// the peer address, typically the tunnel address with the last octet
    /// decremented.
    static var tunnelInterfaceAddress: String? {
        interfaces().first { isTunnelInterface($0.name) && $0.isUp && $0.isRunning }?.ipv4
    }

    /// 所有可能承载 RSD 的回环地址，按可信度排序。
    /// LocalDevVPN 是 `10.7.0.1`，SideStore WireGuard / StikDebug 常见 `172.16.0.1`，
    /// 也有把设备端放在隧道地址减一的实现，所以这里一并列出来逐个探测。
    static func loopbackTargetCandidates() -> [String] {
        var list: [String] = []
        func add(_ value: String?) {
            guard let value, !value.isEmpty, !list.contains(value) else { return }
            list.append(value)
        }
        add(TargetHostConfig.effective)
        add(tunnelInterfaceAddress)
        if let tunnel = tunnelInterfaceAddress {
            let parts = tunnel.split(separator: ".")
            if parts.count == 4, let last = Int(parts[3]), last > 1 {
                add(parts[0...2].joined(separator: ".") + "." + String(last - 1))
            }
        }
        add("172.16.0.1")
        add("10.7.0.1")
        return list
    }

    /// 把单个地址同时设成主目标和候选列表，避免 Rust 层回落到内置地址。
    static func applyTargetHost(_ host: String) {
        guard !host.isEmpty else { return }
        _ = host.withCString { al_set_target_host($0) }
        let duplicated = [strdup(host)]
        defer { duplicated.forEach { free($0) } }
        let pointers = duplicated.map { UnsafePointer($0) }
        pointers.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                _ = al_set_target_hosts(base, buffer.count)
            }
        }
    }

    private static var lastSelectedTarget: String?

    /// 探测回环隧道里真正可连的 RSD 地址并锁定它。
    @discardableResult
    static func selectReachableTarget(force: Bool = false) async -> String? {
        let configured = TargetHostConfig.effective
        let candidates = loopbackTargetCandidates()

        if !force, let cached = lastSelectedTarget, candidates.contains(cached) {
            applyTargetHost(cached)
            return cached
        }

        var reachable: [String] = []
        for host in candidates {
            if await RSDProbe.canConnect(host: host) {
                reachable.append(host)
            }
        }
        AirBeepLog.shared.append(
            "目标探测：\(candidates.joined(separator: ", ")) → "
                + "可连 \(reachable.isEmpty ? "无" : reachable.joined(separator: ", "))"
        )

        let chosen = reachable.contains(configured) ? configured : reachable.first
        guard let chosen else {
            applyTargetHost(configured)
            return nil
        }
        applyTargetHost(chosen)
        lastSelectedTarget = chosen
        AirBeepLog.shared.append("目标：使用 \(chosen):49152")
        return chosen
    }

    /// 只把配置里的回环地址推给 Rust 层。Wi-Fi 地址对 RSD 没用，
    /// 混进候选只会让内核在隧道没起来时误连到别的网段。
    static func syncTargetHostsToAirlift() {
        let configured = TargetHostConfig.effective
        let isCustom = TargetHostConfig.isCustomized
        AirBeepLog.shared.append(
            "network: target=\(configured)\(isCustom ? " (custom)" : "") "
                + "wifi=\(wifiActive) tunnel=\(tunnelInterfaceAddress ?? "down")"
        )
        applyTargetHost(configured)
    }
}