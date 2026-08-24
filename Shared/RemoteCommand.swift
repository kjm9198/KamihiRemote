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
    case releaseAll
    case heartbeat(id: UInt64, timestamp: Double)
    case heartbeatAck(id: UInt64, timestamp: Double)
    case hello(deviceID: String, deviceName: String, capabilities: String)
    case helloAck(sessionID: String, hostName: String, hostID: String, realtimePort: UInt16)
    case pair(code: String, deviceID: String)
    case pairAck(ok: Bool, sessionID: String)
    case keyDown(code: UInt16, flags: UInt64)
    case keyUp(code: UInt16, flags: UInt64)
    case typeText(String)
    case system(SystemAction)
    case media(MediaAction)
    case presentation(PresentationAction)
    case pinch(delta: Double)

    var isRealtime: Bool {
        switch self {
        case .move, .scroll, .pinch:
            return true
        default:
            return false
        }
    }

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
        case .releaseAll:
            return "RELEASE_ALL"
        case .heartbeat(let id, let timestamp):
            return "HEARTBEAT \(id) \(format(timestamp))"
        case .heartbeatAck(let id, let timestamp):
            return "HEARTBEAT_ACK \(id) \(format(timestamp))"
        case .hello(let deviceID, let deviceName, let capabilities):
            return "HELLO \(RemoteConstants.protocolVersion) \(token(deviceID)) \(quoted(deviceName)) \(token(capabilities))"
        case .helloAck(let sessionID, let hostName, let hostID, let realtimePort):
            return "HELLO_ACK \(token(sessionID)) \(quoted(hostName)) \(token(hostID)) \(realtimePort)"
        case .pair(let code, let deviceID):
            return "PAIR \(token(code)) \(token(deviceID))"
        case .pairAck(let ok, let sessionID):
            return "PAIR_ACK \(ok ? "OK" : "FAIL") \(token(sessionID))"
        case .keyDown(let code, let flags):
            return "KEY_DOWN \(code) \(flags)"
        case .keyUp(let code, let flags):
            return "KEY_UP \(code) \(flags)"
        case .typeText(let text):
            return "TYPE \(quoted(text))"
        case .system(let action):
            return "SYSTEM \(action.rawValue)"
        case .media(let action):
            return "MEDIA \(action.rawValue)"
        case .presentation(let action):
            return "PRESENTATION \(action.rawValue)"
        case .pinch(let delta):
            return "PINCH \(format(delta))"
        }
    }

    var payload: Data {
        Data((wire + "\n").utf8)
    }

    var name: String {
        wire.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "UNKNOWN"
    }

    private func format(_ value: Double) -> String {
        RemotePacket.formatCoord(value)
    }

    private func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Mac" : trimmed.replacingOccurrences(of: "\n", with: " ")
    }

    private func token(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed.replacingOccurrences(of: " ", with: "_")
    }

    private func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }
}
