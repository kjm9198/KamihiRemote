import Foundation

enum RemoteCommand: Equatable, Sendable {
    case ping
    case pong(hostName: String)
    case move(dx: Double, dy: Double)
    case click
    case rightClick
    case scroll(dx: Double, dy: Double)
    case mouseDown
    case mouseUp

    var wire: String {
        switch self {
        case .ping:
            return "PING"
        case .pong(let hostName):
            return "PONG \(sanitized(hostName))"
        case .move(let dx, let dy):
            return "MOVE \(format(dx)) \(format(dy))"
        case .click:
            return "CLICK"
        case .rightClick:
            return "RIGHT_CLICK"
        case .scroll(let dx, let dy):
            return "SCROLL \(format(dx)) \(format(dy))"
        case .mouseDown:
            return "MOUSE_DOWN"
        case .mouseUp:
            return "MOUSE_UP"
        }
    }

    var payload: Data {
        Data((wire + "\n").utf8)
    }

    static func parse(_ raw: String) -> RemoteCommand? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        let parts = line.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard let verb = parts.first?.uppercased() else { return nil }
        let rest = parts.count > 1 ? String(parts[1]) : ""

        switch verb {
        case "PING":
            return .ping
        case "PONG":
            return .pong(hostName: rest.isEmpty ? "Mac" : rest)
        case "MOVE":
            guard let pair = doubles(from: rest) else { return nil }
            return .move(dx: pair.0, dy: pair.1)
        case "CLICK":
            return .click
        case "RIGHT_CLICK":
            return .rightClick
        case "SCROLL":
            guard let pair = doubles(from: rest) else { return nil }
            return .scroll(dx: pair.0, dy: pair.1)
        case "MOUSE_DOWN":
            return .mouseDown
        case "MOUSE_UP":
            return .mouseUp
        default:
            return nil
        }
    }

    private func format(_ value: Double) -> String {
        RemotePacket.formatCoord(value)
    }

    private func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Mac" : trimmed.replacingOccurrences(of: "\n", with: " ")
    }

    private static func doubles(from rest: String) -> (Double, Double)? {
        let numbers = rest.split(whereSeparator: \.isWhitespace)
        guard numbers.count >= 2,
              let dx = RemotePacket.parseDouble(String(numbers[0])),
              let dy = RemotePacket.parseDouble(String(numbers[1]))
        else { return nil }
        return (dx, dy)
    }
}
