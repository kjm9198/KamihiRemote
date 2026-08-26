import Foundation
import Darwin

enum LocalIPAddress {
    static func primaryIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var fallback: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }

            guard let address = interface.pointee.ifa_addr else { continue }
            let name = String(cString: interface.pointee.ifa_name)
            let family = address.pointee.sa_family

            guard family == UInt8(AF_INET), name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            let ip = String(cString: hostname)
            guard ip.isEmpty == false, ip != "127.0.0.1" else { continue }

            if name == "en0" {
                return ip
            }
            fallback = fallback ?? ip
        }

        return fallback
    }
}
