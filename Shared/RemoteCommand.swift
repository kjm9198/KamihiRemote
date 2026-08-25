import Foundation

struct ControllerState: Equatable, Sendable {
    var sequence: UInt32 = 0
    var timestamp: Double = 0
    var leftX: Float = 0
    var leftY: Float = 0
    var rightX: Float = 0
    var rightY: Float = 0
    var leftTrigger: Float = 0
    var rightTrigger: Float = 0
    var buttons: UInt32 = 0
    var dpad: UInt8 = 0

    static let neutral = ControllerState()

    var isNeutral: Bool {
        buttons == 0
            && dpad == 0
            && abs(leftX) < 0.02 && abs(leftY) < 0.02
            && abs(rightX) < 0.02 && abs(rightY) < 0.02
            && leftTrigger < 0.02 && rightTrigger < 0.02
    }

    mutating func set(_ button: ControllerButton, down: Bool) {
        let bit: UInt32 = 1 << button.rawValue
        if down { buttons |= bit } else { buttons &= ~bit }
    }

    func isDown(_ button: ControllerButton) -> Bool {
        buttons & (1 << button.rawValue) != 0
    }
}

enum ControllerButton: Int, CaseIterable, Codable, Sendable {
    case a, b, x, y, l1, r1, menu, view, start, l3, r3

    var title: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .l1: return "L1"
        case .r1: return "R1"
        case .menu: return "Menu"
        case .view: return "View"
        case .start: return "Start"
        case .l3: return "L3"
        case .r3: return "R3"
        }
    }
}

enum ControllerProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case mac, gaming, presentation, editing, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mac: return "Mac Navigation"
        case .gaming: return "Gaming (WASD)"
        case .presentation: return "Presentation"
        case .editing: return "Editing & Shortcuts"
        case .custom: return "Custom"
        }
    }
}

enum ControllerAction: Codable, Equatable, Sendable, Hashable {
    case none
    case key(code: UInt16, title: String)
    case shortcut(spec: String, title: String)
    case click
    case rightClick
    case system(SystemAction)
    case media(MediaAction)
    case presentation(PresentationAction)
    case openApp(bundleID: String, name: String)
    case openURL(url: String, name: String)

    var title: String {
        switch self {
        case .none: return "None"
        case .key(_, let title): return title
        case .shortcut(_, let title): return title
        case .click: return "Left Click"
        case .rightClick: return "Right Click"
        case .system(let sys): return sys.title
        case .media(let med): return "Media: \(med)"
        case .presentation(let pres): return "Presentation: \(pres)"
        case .openApp(_, let name): return "App: \(name)"
        case .openURL(_, let name): return "URL: \(name)"
        }
    }
}

enum StickAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case wasd, arrows, mouse, scroll, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wasd: return "WASD Keys"
        case .arrows: return "Arrow Keys"
        case .mouse: return "Mouse Look / Pointer"
        case .scroll: return "Scroll Wheel"
        case .none: return "Disabled"
        }
    }
}

struct ControllerMapping: Codable, Equatable, Sendable {
    var profile: ControllerProfile = .mac
    var a: ControllerAction = .key(code: 49, title: "Space")
    var b: ControllerAction = .key(code: 53, title: "Escape")
    var x: ControllerAction = .shortcut(spec: "cmd+c", title: "Copy (⌘C)")
    var y: ControllerAction = .shortcut(spec: "cmd+v", title: "Paste (⌘V)")
    var dpadUp: ControllerAction = .key(code: 126, title: "Up Arrow")
    var dpadDown: ControllerAction = .key(code: 125, title: "Down Arrow")
    var dpadLeft: ControllerAction = .system(.previousDesktop)
    var dpadRight: ControllerAction = .system(.nextDesktop)
    var l1: ControllerAction = .system(.missionControl)
    var r1: ControllerAction = .system(.appExpose)
    var l2: ControllerAction = .media(.volumeDown)
    var r2: ControllerAction = .media(.volumeUp)
    var start: ControllerAction = .key(code: 36, title: "Return")
    var menu: ControllerAction = .shortcut(spec: "cmd+tab", title: "App Switcher (⌘Tab)")
    var view: ControllerAction = .system(.showDesktop)
    var l3: ControllerAction = .none
    var r3: ControllerAction = .none
    var leftStick: StickAction = .scroll
    var rightStick: StickAction = .mouse

    static let mac = ControllerMapping(
        profile: .mac,
        a: .key(code: 49, title: "Space"),
        b: .key(code: 53, title: "Escape"),
        x: .shortcut(spec: "cmd+c", title: "Copy (⌘C)"),
        y: .shortcut(spec: "cmd+v", title: "Paste (⌘V)"),
        dpadUp: .key(code: 126, title: "Up Arrow"),
        dpadDown: .key(code: 125, title: "Down Arrow"),
        dpadLeft: .system(.previousDesktop),
        dpadRight: .system(.nextDesktop),
        l1: .system(.missionControl),
        r1: .system(.appExpose),
        l2: .media(.volumeDown),
        r2: .media(.volumeUp),
        start: .key(code: 36, title: "Return"),
        menu: .shortcut(spec: "cmd+tab", title: "App Switcher (⌘Tab)"),
        view: .system(.showDesktop),
        l3: .none,
        r3: .none,
        leftStick: .scroll,
        rightStick: .mouse
    )

    static let gaming = ControllerMapping(
        profile: .gaming,
        a: .key(code: 49, title: "Jump (Space)"),
        b: .key(code: 56, title: "Sprint (Shift)"),
        x: .key(code: 14, title: "Interact (E)"),
        y: .key(code: 3, title: "Flashlight / Use (F)"),
        dpadUp: .key(code: 126, title: "Up Arrow"),
        dpadDown: .key(code: 125, title: "Down Arrow"),
        dpadLeft: .key(code: 123, title: "Left Arrow"),
        dpadRight: .key(code: 124, title: "Right Arrow"),
        l1: .key(code: 12, title: "Grenade / Ability (Q)"),
        r1: .key(code: 15, title: "Reload (R)"),
        l2: .rightClick,
        r2: .click,
        start: .key(code: 53, title: "Pause (Escape)"),
        menu: .key(code: 48, title: "Scoreboard (Tab)"),
        view: .key(code: 46, title: "Map (M)"),
        l3: .key(code: 59, title: "Crouch (Control)"),
        r3: .key(code: 49, title: "Melee (Space)"),
        leftStick: .wasd,
        rightStick: .mouse
    )

    static let presentation = ControllerMapping(
        profile: .presentation,
        a: .presentation(.next),
        b: .presentation(.previous),
        x: .presentation(.black),
        y: .presentation(.start),
        dpadUp: .media(.volumeUp),
        dpadDown: .media(.volumeDown),
        dpadLeft: .presentation(.previous),
        dpadRight: .presentation(.next),
        l1: .media(.volumeDown),
        r1: .media(.volumeUp),
        l2: .presentation(.previous),
        r2: .presentation(.next),
        start: .presentation(.start),
        menu: .presentation(.end),
        view: .system(.missionControl),
        l3: .none,
        r3: .none,
        leftStick: .scroll,
        rightStick: .mouse
    )

    static let editing = ControllerMapping(
        profile: .editing,
        a: .key(code: 36, title: "Return"),
        b: .key(code: 53, title: "Escape"),
        x: .shortcut(spec: "cmd+c", title: "Copy (⌘C)"),
        y: .shortcut(spec: "cmd+v", title: "Paste (⌘V)"),
        dpadUp: .key(code: 126, title: "Up Arrow"),
        dpadDown: .key(code: 125, title: "Down Arrow"),
        dpadLeft: .key(code: 123, title: "Left Arrow"),
        dpadRight: .key(code: 124, title: "Right Arrow"),
        l1: .shortcut(spec: "cmd+z", title: "Undo (⌘Z)"),
        r1: .shortcut(spec: "cmd+shift+z", title: "Redo (⌘⇧Z)"),
        l2: .key(code: 51, title: "Delete (⌫)"),
        r2: .key(code: 49, title: "Space"),
        start: .shortcut(spec: "cmd+s", title: "Save (⌘S)"),
        menu: .shortcut(spec: "cmd+a", title: "Select All (⌘A)"),
        view: .shortcut(spec: "cmd+f", title: "Find (⌘F)"),
        l3: .none,
        r3: .none,
        leftStick: .scroll,
        rightStick: .mouse
    )

    static func defaultFor(profile: ControllerProfile) -> ControllerMapping {
        switch profile {
        case .mac: return .mac
        case .gaming: return .gaming
        case .presentation: return .presentation
        case .editing: return .editing
        case .custom:
            var custom = ControllerMapping.mac
            custom.profile = .custom
            return custom
        }
    }
}

enum DPadDirection: UInt8, Sendable {
    case none = 0
    case up = 1
    case upRight = 2
    case right = 3
    case downRight = 4
    case down = 5
    case downLeft = 6
    case left = 7
    case upLeft = 8
}

struct HostAppEntry: Equatable, Identifiable, Codable, Sendable {
    var id: String { bundleIdentifier }
    var displayName: String
    var bundleIdentifier: String
    var catalogPath: String? = nil
}

indirect enum RemoteCommand: Equatable, Sendable {
    case ping
    case pong(hostName: String)
    case move(dx: Double, dy: Double)
    case click
    case doubleClick
    case rightClick
    case scroll(dx: Double, dy: Double, phase: ScrollPhase)
    case mouseDown
    case mouseUp
    case releaseAll
    case heartbeat(id: UInt64, timestamp: Double)
    case heartbeatAck(id: UInt64, timestamp: Double)
    case hello(deviceID: String, deviceName: String, capabilities: String)
    case helloAck(sessionID: String, hostName: String, hostID: String, realtimePort: UInt16)
    case pair(code: String, deviceID: String)
    case pairAck(ok: Bool, sessionID: String)
    case pairRequest(deviceID: String, deviceName: String, publicKey: String, code: String)
    case pairDecision(ok: Bool, deviceID: String, sessionMaterial: String)
    case keyDown(code: UInt16, flags: UInt64)
    case keyUp(code: UInt16, flags: UInt64)
    case typeText(String)
    case system(SystemAction)
    case media(MediaAction)
    case presentation(action: PresentationAction, profile: PresentationProfile)
    case pinch(delta: Double)
    case zoom(ZoomAction)
    case openApp(bundleID: String)
    case openURL(String)
    case shortcut(String)
    case requestAppList
    case appListBegin(count: Int)
    case appEntry(name: String, bundleID: String)
    case appListEnd
    case laser(x: Double, y: Double)
    case laserVisible(Bool)
    case controller(ControllerState)
    case revokeDevice(deviceID: String)
    case action(id: String, inner: RemoteCommand)
    case actionAck(id: String, success: Bool, message: String)
    case requestFocusedText
    case focusedText(status: FocusedTextStatus, value: String)
    case syncControllerMapping(ControllerMapping)

    var isRealtime: Bool {
        switch self {
        case .move, .scroll, .pinch, .laser, .controller:
            return true
        default:
            return false
        }
    }

    var isController: Bool {
        if case .controller = self { return true }
        return false
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
        case .doubleClick:
            return "DOUBLE_CLICK"
        case .rightClick:
            return "RIGHT_CLICK"
        case .scroll(let dx, let dy, let phase):
            return "SCROLL \(format(dx)) \(format(dy)) \(phase.rawValue)"
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
        case .pairRequest(let deviceID, let deviceName, let publicKey, let code):
            return "PAIR_REQUEST \(token(deviceID)) \(quoted(deviceName)) \(token(publicKey)) \(token(code))"
        case .pairDecision(let ok, let deviceID, let sessionMaterial):
            return "PAIR_DECISION \(ok ? "OK" : "FAIL") \(token(deviceID)) \(token(sessionMaterial))"
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
        case .presentation(let action, let profile):
            return "PRESENTATION \(action.rawValue) \(profile.rawValue)"
        case .pinch(let delta):
            return "PINCH \(format(delta))"
        case .zoom(let action):
            return "ZOOM \(action.rawValue)"
        case .openApp(let bundleID):
            return "OPEN_APP \(token(bundleID))"
        case .openURL(let url):
            return "OPEN_URL \(quoted(url))"
        case .shortcut(let spec):
            return "SHORTCUT \(token(spec))"
        case .requestAppList:
            return "REQUEST_APP_LIST"
        case .appListBegin(let count):
            return "APP_LIST_BEGIN \(count)"
        case .appEntry(let name, let bundleID):
            return "APP_ENTRY \(quoted(name)) \(token(bundleID))"
        case .appListEnd:
            return "APP_LIST_END"
        case .laser(let x, let y):
            return "LASER \(format(x)) \(format(y))"
        case .laserVisible(let visible):
            return "LASER_VISIBLE \(visible ? "1" : "0")"
        case .controller(let state):
            return [
                "CONTROLLER",
                "\(state.sequence)",
                format(state.timestamp),
                format(Double(state.leftX)),
                format(Double(state.leftY)),
                format(Double(state.rightX)),
                format(Double(state.rightY)),
                format(Double(state.leftTrigger)),
                format(Double(state.rightTrigger)),
                "\(state.buttons)",
                "\(state.dpad)"
            ].joined(separator: " ")
        case .revokeDevice(let deviceID):
            return "REVOKE \(token(deviceID))"
        case .action(let id, let inner):
            return "ACTION \(token(id)) \(inner.wire)"
        case .actionAck(let id, let success, let message):
            return "ACTION_ACK \(token(id)) \(success ? "OK" : "FAIL") \(quoted(message))"
        case .requestFocusedText:
            return "REQUEST_FOCUSED_TEXT"
        case .focusedText(let status, let value):
            return "FOCUSED_TEXT \(status.rawValue) \(quoted(value))"
        case .syncControllerMapping(let mapping):
            let json = (try? JSONEncoder().encode(mapping)) ?? Data()
            return "CONTROLLER_CONFIG \(json.base64EncodedString())"
        }
    }

    /// Deck, keyboard, presentation, and system gestures need an execution ACK over TCP.
    var shouldAcknowledge: Bool {
        switch self {
        case .system, .openApp, .openURL, .shortcut, .media, .presentation, .typeText, .requestFocusedText:
            return true
        case .action, .zoom:
            return false
        default:
            return false
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
