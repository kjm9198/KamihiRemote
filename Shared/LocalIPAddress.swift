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
            let name = String(cString: interface.pointee.ifa_name)
            let family = interface.pointee.ifa_addr.pointee.sa_family

            if family == UInt8(AF_INET), name.hasPrefix("en") {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.pointee.ifa_addr,
                    socklen_t(interface.pointee.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                let ip = String(cString: hostname)
                if ip != "127.0.0.1" {
                    if name == "en0" {
                        return ip
                    }
                    fallback = fallback ?? ip
                }
            }

            pointer = interface.pointee.ifa_next
        }

        return fallback
    }
}
