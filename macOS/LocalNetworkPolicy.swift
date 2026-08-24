import Foundation
import Network

enum LocalNetworkPolicy {
    static func allows(_ connection: NWConnection) -> Bool {
        switch connection.endpoint {
        case .hostPort(let host, _):
            return allows(host)
        case .service:
            return true
        default:
            return true
        }
    }

    static func allows(_ host: NWEndpoint.Host) -> Bool {
        switch host {
        case .ipv4(let address):
            return isLocalIPv4(address)
        case .ipv6(let address):
            return isLocalIPv6(address)
        case .name(let name, _):
            if let ipv4 = IPv4Address(name) {
                return isLocalIPv4(ipv4)
            }
            let stripped = NetworkEndpoint.sanitizeHost(name)
            if let ipv6 = IPv6Address(stripped) {
                return isLocalIPv6(ipv6)
            }
            return name.lowercased().contains(".local")
        @unknown default:
            return true
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
        if bytes[0] == 0xff { return false }
        return true
    }
}
