import Foundation
import Network

enum LocalNetworkPolicy {
    static func allows(_ connection: NWConnection) -> Bool {
        switch connection.endpoint {
        case .hostPort(let host, _):
            return allows(host)
        default:
            return false
        }
    }

    static func allows(_ host: NWEndpoint.Host) -> Bool {
        switch host {
        case .ipv4(let address):
            return isPrivateIPv4(address)
        case .ipv6(let address):
            return isLocalIPv6(address)
        case .name(let name, _):
            if let ipv4 = IPv4Address(name) {
                return isPrivateIPv4(ipv4)
            }
            return false
        @unknown default:
            return false
        }
    }

    private static func isPrivateIPv4(_ address: IPv4Address) -> Bool {
        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 4 else { return false }
        let a = bytes[0]
        let b = bytes[1]
        if a == 10 { return true }
        if a == 127 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        return false
    }

    private static func isLocalIPv6(_ address: IPv6Address) -> Bool {
        if address.isLoopback || address.isLinkLocal { return true }
        let bytes = [UInt8](address.rawValue)
        guard bytes.count == 16 else { return false }
        return bytes[0] & 0xfe == 0xfc
    }
}
