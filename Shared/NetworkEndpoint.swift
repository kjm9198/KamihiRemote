import Foundation
import Network

enum NetworkEndpoint {
    static func looksLikeNumericHost(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if IPv4Address(trimmed) != nil { return true }
        let stripped = stripInterface(trimmed)
        return IPv6Address(stripped) != nil
    }

    static func bonjourService(name: String) -> NWEndpoint {
        .service(
            name: name,
            type: RemoteConstants.bonjourType,
            domain: RemoteConstants.bonjourDomain,
            interface: nil
        )
    }

    static func sanitizeHost(_ value: String) -> String {
        stripInterface(value.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
    }

    static func hostString(from endpoint: NWEndpoint?) -> String? {
        guard case .hostPort(let host, _) = endpoint else { return nil }
        return sanitizeHost("\(host)")
    }

    private static func stripInterface(_ value: String) -> String {
        var stripped = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if let index = stripped.firstIndex(of: "%") {
            stripped = String(stripped[..<index])
        }
        return stripped
    }
}
