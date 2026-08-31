import Foundation
import Network

enum LocalNetworkPolicy {
    static func allows(_ connection: NWConnection) -> Bool {
        switch connection.endpoint {
        case .hostPort(let host, _):
            return allows(host)
        default:
            // Incoming remote-control traffic must resolve to an address we can
            // positively classify as local. Unknown endpoint kinds fail closed.
            return false
        }
    }

    static func allows(_ host: NWEndpoint.Host) -> Bool {
        switch host {
        case .ipv4(let address):
            return isLocalIPv4(address)
        case .ipv6(let address):
            return isLocalIPv6(address)
        case .name(let name, _):
            let normalized = NetworkEndpoint.sanitizeHost(name).lowercased()
            if normalized == "localhost" || normalized.hasSuffix(".local") {
                return true
            }
            if let ipv4 = IPv4Address(normalized) {
                return isLocalIPv4(ipv4)
            }
            if let ipv6 = IPv6Address(normalized) {
                return isLocalIPv6(ipv6)
            }
            return false
        @unknown default:
            return false
        }
    }

    private static func isLocalIPv4(_ address: IPv4Address) -> Bool {
        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 4 else { return false }
        let a = bytes[0]
        let b = bytes[1]
        if a == 10 { return true }
        if a == 127 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 169 && b == 254 { return true }
        return false
    }

    private static func isLocalIPv6(_ address: IPv6Address) -> Bool {
        if address.isLoopback || address.isLinkLocal { return true }
        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 16 else { return false }

        // fc00::/7 — IPv6 Unique Local Address space. This is the IPv6 analogue
        // of RFC1918 private addressing and is not globally routed.
        if (bytes[0] & 0xfe) == 0xfc { return true }

        // Accept IPv4-mapped IPv6 only when the embedded IPv4 address itself is
        // private, loopback, or link-local.
        let isIPv4Mapped = bytes[0..<10].allSatisfy { $0 == 0 } && bytes[10] == 0xff && bytes[11] == 0xff
        if isIPv4Mapped,
           let mapped = IPv4Address(Data(bytes[12..<16])) {
            return isLocalIPv4(mapped)
        }

        // Global unicast, multicast, documentation and every other IPv6 range
        // are denied by default.
        return false
    }
}
