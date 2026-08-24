import Foundation

enum RemotePacketResult: Equatable {
    case success(token: String, command: RemoteCommand, legacy: Bool, sessionID: String?, sequence: UInt64?)
    case failure(String)
}

enum RemotePacket {
    static func parse(_ raw: String) -> RemotePacketResult {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return .failure("empty packet") }

        if line.hasPrefix("K2 ") {
            return parseV2(line)
        }
        return parseV1(line)
    }

    static func parseDouble(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    static func formatCoord(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    static func encodeV1(token: String, command: RemoteCommand) -> Data {
        Data("\(token) \(command.wire)\n".utf8)
    }

    static func encodeV2(sessionID: String, sequence: UInt64, command: RemoteCommand) -> Data {
        let ts = formatCoord(Date().timeIntervalSince1970)
        return Data("K2 \(sessionID) \(sequence) \(ts) \(command.wire)\n".utf8)
    }

    @discardableResult
    static func runSelfChecks() -> Bool {
        func coordsMatch(_ a: Double, _ b: Double) -> Bool {
            abs(a - b) < 0.000001
        }
        func expectSuccess(_ raw: String, token expectedToken: String, _ expected: RemoteCommand, legacy expectedLegacy: Bool = false) {
            switch parse(raw) {
            case .success(let token, let command, let legacy, _, _):
                precondition(token == expectedToken, "Auth mismatch for \(raw): \(token)")
                precondition(legacy == expectedLegacy, "Legacy flag mismatch for \(raw)")
                switch (command, expected) {
                case (.ping, .ping), (.click, .click), (.rightClick, .rightClick), (.mouseDown, .mouseDown), (.mouseUp, .mouseUp), (.releaseAll, .releaseAll):
                    break
                case let (.move(dx, dy), .move(ex, ey)):
                    precondition(coordsMatch(dx, ex) && coordsMatch(dy, ey), "Vector mismatch for \(raw)")
                case let (.scroll(dx, dy, phase), .scroll(ex, ey, expectedPhase)):
                    precondition(coordsMatch(dx, ex) && coordsMatch(dy, ey) && phase == expectedPhase, "Scroll mismatch for \(raw)")
                case let (.pong(name), .pong(expectedName)):
                    precondition(name == expectedName)
                default:
                    precondition(command == expected, "Unexpected parse for \(raw): \(command)")
                }
            case .failure(let reason):
                preconditionFailure("Expected success for \(raw), got \(reason)")
            }
        }

        expectSuccess("163158 MOVE 1.289 0.645", token: "163158", .move(dx: 1.289, dy: 0.645))
        expectSuccess("163158 MOVE -5.2 3.9", token: "163158", .move(dx: -5.2, dy: 3.9))
        expectSuccess("163158 MOVE 0 0", token: "163158", .move(dx: 0, dy: 0))
        expectSuccess("163158 MOVE 0.0 0.0", token: "163158", .move(dx: 0, dy: 0))
        expectSuccess("163158 MOVE 120.5 -80.25", token: "163158", .move(dx: 120.5, dy: -80.25))
        expectSuccess("163158 PING", token: "163158", .ping)
        expectSuccess("163158 CLICK", token: "163158", .click)
        expectSuccess("163158 DOUBLE_CLICK", token: "163158", .doubleClick)
        expectSuccess("163158 RELEASE_ALL", token: "163158", .releaseAll)
        expectSuccess("163158 MOUSE_DOWN", token: "163158", .mouseDown)
        expectSuccess("163158 MOUSE_UP", token: "163158", .mouseUp)
        expectSuccess("163158 SCROLL 1.5 -4.0", token: "163158", .scroll(dx: 1.5, dy: -4.0, phase: .changed))
        expectSuccess("163158 SCROLL 1.5 -4.0 ended", token: "163158", .scroll(dx: 1.5, dy: -4.0, phase: .ended))
        expectSuccess("163158 PRESENTATION next", token: "163158", .presentation(action: .next, profile: .keynote))
        expectSuccess("163158 PRESENTATION start powerpoint", token: "163158", .presentation(action: .start, profile: .powerpoint))
        expectSuccess("163158 OPEN_APP com.apple.Safari", token: "163158", .openApp(bundleID: "com.apple.Safari"))
        expectSuccess("163158 SHORTCUT cmd+c", token: "163158", .shortcut("cmd+c"))
        expectSuccess("MOVE 163158 1.289 0.645", token: "163158", .move(dx: 1.289, dy: 0.645), legacy: true)

        switch parse("K2 sess-1 103 1710000000.000 MOVE 1.289 0.645") {
        case .success(let token, let command, _, let session, let seq):
            precondition(token == "sess-1")
            precondition(session == "sess-1")
            precondition(seq == 103)
            guard case .move(let dx, let dy) = command, coordsMatch(dx, 1.289), coordsMatch(dy, 0.645) else {
                preconditionFailure("v2 MOVE parse failed")
            }
        case .failure(let reason):
            preconditionFailure("v2 MOVE should parse: \(reason)")
        }

        if case .success(let token, let command, _, _, _) = parse("000000 MOVE 1 2") {
            precondition(token == "000000")
            guard case .move = command else { preconditionFailure("bad pairing code still parses command") }
        } else {
            preconditionFailure("wrong pairing code should still decode")
        }
        guard case .failure(let empty) = parse("") else { preconditionFailure("empty packet should fail") }
        precondition(empty == "empty packet")
        guard case .failure(let missingCommand) = parse("163158") else { preconditionFailure("token-only packet should fail") }
        precondition(missingCommand == "missing command")
        guard case .failure(let unknown) = parse("163158 JUMP 1 2") else { preconditionFailure("unknown command should fail") }
        precondition(unknown.contains("unknown command"))
        guard case .failure(let missingDx) = parse("163158 MOVE") else { preconditionFailure("MOVE without args should fail") }
        precondition(missingDx == "MOVE missing dx")
        guard case .failure(let missingDy) = parse("163158 MOVE 1.2") else { preconditionFailure("MOVE without dy should fail") }
        precondition(missingDy == "MOVE missing dy")
        guard case .failure(let invalidDx) = parse("163158 MOVE foo 0.5") else { preconditionFailure("invalid MOVE dx should fail") }
        precondition(invalidDx == "MOVE dx invalid")
        guard case .failure(let invalidDy) = parse("163158 MOVE 0.5 bar") else { preconditionFailure("invalid MOVE dy should fail") }
        precondition(invalidDy == "MOVE dy invalid")
        SequenceGate.runSelfChecks()
        NSLog("Kamihi parser self-checks passed")
        return true
    }

    private static func parseV1(_ line: String) -> RemotePacketResult {
        var parts = tokenize(line)
        guard !parts.isEmpty else { return .failure("empty packet") }

        var legacy = false
        if looksLikeCommand(parts[0]), parts.count >= 2, PairingSecret.isValid(parts[1]) {
            legacy = true
            let command = parts.remove(at: 0)
            let token = parts.remove(at: 0)
            parts.insert(contentsOf: [token, command], at: 0)
        }

        guard parts.count >= 2 else { return .failure("missing command") }
        return decode(token: parts[0], command: parts[1], args: Array(parts.dropFirst(2)), legacy: legacy, sessionID: nil, sequence: nil)
    }

    private static func parseV2(_ line: String) -> RemotePacketResult {
        let parts = tokenize(line)
        guard parts.count >= 5 else { return .failure("missing command") }
        let session = parts[1]
        guard let sequence = UInt64(parts[2]) else { return .failure("invalid sequence") }
        return decode(token: session, command: parts[4], args: Array(parts.dropFirst(5)), legacy: false, sessionID: session, sequence: sequence)
    }

    private static func decode(token: String, command rawCommand: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?) -> RemotePacketResult {
        let command = rawCommand.uppercased()
        switch command {
        case "PING":
            return .success(token: token, command: .ping, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PONG":
            let name = unquote(args.joined(separator: " "))
            return .success(token: token, command: .pong(hostName: name.isEmpty ? "Mac" : name), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "MOVE":
            return parseVector(token: token, command: "MOVE", args: args, legacy: legacy, sessionID: sessionID, sequence: sequence) { .move(dx: $0, dy: $1) }
        case "CLICK":
            return .success(token: token, command: .click, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "DOUBLE_CLICK":
            return .success(token: token, command: .doubleClick, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "RIGHT_CLICK":
            return .success(token: token, command: .rightClick, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "SCROLL":
            return parseScroll(token: token, args: args, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "MOUSE_DOWN":
            return .success(token: token, command: .mouseDown, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "MOUSE_UP":
            return .success(token: token, command: .mouseUp, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "RELEASE_ALL":
            return .success(token: token, command: .releaseAll, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "HEARTBEAT":
            guard args.count >= 2, let id = UInt64(args[0]), let ts = parseDouble(args[1]) else { return .failure("HEARTBEAT invalid") }
            return .success(token: token, command: .heartbeat(id: id, timestamp: ts), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "HEARTBEAT_ACK":
            guard args.count >= 2, let id = UInt64(args[0]), let ts = parseDouble(args[1]) else { return .failure("HEARTBEAT_ACK invalid") }
            return .success(token: token, command: .heartbeatAck(id: id, timestamp: ts), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "HELLO":
            guard args.count >= 3 else { return .failure("HELLO missing fields") }
            let deviceID = args.count > 1 ? args[1] : "-"
            let deviceName = unquote(args.dropFirst(2).dropLast().joined(separator: " "))
            let capabilities = args.last ?? "-"
            return .success(token: token, command: .hello(deviceID: deviceID, deviceName: deviceName.isEmpty ? "iPhone" : deviceName, capabilities: capabilities), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "HELLO_ACK":
            guard args.count >= 4, let port = UInt16(args[3]) else { return .failure("HELLO_ACK missing fields") }
            return .success(token: token, command: .helloAck(sessionID: args[0], hostName: unquote(args[1]), hostID: args[2], realtimePort: port), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PAIR":
            guard args.count >= 2 else { return .failure("PAIR missing fields") }
            return .success(token: token, command: .pair(code: args[0], deviceID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PAIR_ACK":
            guard args.count >= 2 else { return .failure("PAIR_ACK missing fields") }
            return .success(token: token, command: .pairAck(ok: args[0].uppercased() == "OK", sessionID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "KEY_DOWN":
            guard args.count >= 2, let code = UInt16(args[0]), let flags = UInt64(args[1]) else { return .failure("KEY_DOWN invalid") }
            return .success(token: token, command: .keyDown(code: code, flags: flags), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "KEY_UP":
            guard args.count >= 2, let code = UInt16(args[0]), let flags = UInt64(args[1]) else { return .failure("KEY_UP invalid") }
            return .success(token: token, command: .keyUp(code: code, flags: flags), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "TYPE":
            return .success(token: token, command: .typeText(unquote(args.joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "SYSTEM":
            guard let raw = args.first, let action = SystemAction(rawValue: raw) else { return .failure("unknown system action") }
            return .success(token: token, command: .system(action), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "MEDIA":
            guard let raw = args.first, let action = MediaAction(rawValue: raw) else { return .failure("unknown media action") }
            return .success(token: token, command: .media(action), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PRESENTATION":
            guard let raw = args.first, let action = PresentationAction(rawValue: raw) else { return .failure("unknown presentation action") }
            let profile = args.dropFirst().first.flatMap(PresentationProfile.init(rawValue:)) ?? .keynote
            return .success(token: token, command: .presentation(action: action, profile: profile), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PINCH":
            guard let delta = args.first.flatMap(parseDouble) else { return .failure("PINCH invalid") }
            return .success(token: token, command: .pinch(delta: delta), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "ZOOM":
            guard let raw = args.first, let action = ZoomAction(rawValue: raw) else { return .failure("ZOOM invalid") }
            return .success(token: token, command: .zoom(action), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "OPEN_APP":
            guard let bundle = args.first, bundle.isEmpty == false else { return .failure("OPEN_APP missing bundle") }
            return .success(token: token, command: .openApp(bundleID: bundle), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "OPEN_URL":
            return .success(token: token, command: .openURL(unquote(args.joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "SHORTCUT":
            guard let spec = args.first else { return .failure("SHORTCUT missing spec") }
            return .success(token: token, command: .shortcut(spec), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "REQUEST_APP_LIST":
            return .success(token: token, command: .requestAppList, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "APP_LIST_BEGIN":
            let count = args.first.flatMap { Int($0) } ?? 0
            return .success(token: token, command: .appListBegin(count: count), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "APP_ENTRY":
            guard args.count >= 2 else { return .failure("APP_ENTRY missing fields") }
            return .success(token: token, command: .appEntry(name: unquote(args[0]), bundleID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "APP_LIST_END":
            return .success(token: token, command: .appListEnd, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "LASER":
            return parseVector(token: token, command: "LASER", args: args, legacy: legacy, sessionID: sessionID, sequence: sequence) { .laser(x: $0, y: $1) }
        case "LASER_VISIBLE":
            let visible = (args.first ?? "0") != "0"
            return .success(token: token, command: .laserVisible(visible), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "CONTROLLER":
            return parseController(token: token, args: args, legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PAIR_REQUEST":
            guard args.count >= 4 else { return .failure("PAIR_REQUEST missing fields") }
            return .success(token: token, command: .pairRequest(deviceID: args[0], deviceName: unquote(args[1]), publicKey: args[2], code: args[3]), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "PAIR_DECISION":
            guard args.count >= 3 else { return .failure("PAIR_DECISION missing fields") }
            return .success(token: token, command: .pairDecision(ok: args[0].uppercased() == "OK", deviceID: args[1], sessionMaterial: args[2]), legacy: legacy, sessionID: sessionID, sequence: sequence)
        case "REVOKE":
            guard let deviceID = args.first else { return .failure("REVOKE missing device") }
            return .success(token: token, command: .revokeDevice(deviceID: deviceID), legacy: legacy, sessionID: sessionID, sequence: sequence)
        default:
            return .failure("unknown command \"\(command)\"")
        }
    }

    private static func parseScroll(token: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?) -> RemotePacketResult {
        guard args.count >= 1 else { return .failure("SCROLL missing dx") }
        guard args.count >= 2 else { return .failure("SCROLL missing dy") }
        guard let dx = parseDouble(args[0]) else { return .failure("SCROLL dx invalid") }
        guard let dy = parseDouble(args[1]) else { return .failure("SCROLL dy invalid") }
        let phase = args.count >= 3 ? (ScrollPhase(rawValue: args[2]) ?? .changed) : .changed
        return .success(token: token, command: .scroll(dx: dx, dy: dy, phase: phase), legacy: legacy, sessionID: sessionID, sequence: sequence)
    }

    private static func parseController(token: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?) -> RemotePacketResult {
        guard args.count >= 10,
              let seq = UInt32(args[0]),
              let ts = parseDouble(args[1]),
              let lx = parseDouble(args[2]),
              let ly = parseDouble(args[3]),
              let rx = parseDouble(args[4]),
              let ry = parseDouble(args[5]),
              let lt = parseDouble(args[6]),
              let rt = parseDouble(args[7]),
              let buttons = UInt32(args[8]),
              let dpad = UInt8(args[9])
        else { return .failure("CONTROLLER invalid") }
        let state = ControllerState(
            sequence: seq,
            timestamp: ts,
            leftX: Float(lx),
            leftY: Float(ly),
            rightX: Float(rx),
            rightY: Float(ry),
            leftTrigger: Float(lt),
            rightTrigger: Float(rt),
            buttons: buttons,
            dpad: dpad
        )
        return .success(token: token, command: .controller(state), legacy: legacy, sessionID: sessionID, sequence: sequence)
    }

    private static func parseVector(
        token: String,
        command: String,
        args: [String],
        legacy: Bool,
        sessionID: String?,
        sequence: UInt64?,
        make: (Double, Double) -> RemoteCommand
    ) -> RemotePacketResult {
        guard args.count >= 1 else { return .failure("\(command) missing dx") }
        guard args.count >= 2 else { return .failure("\(command) missing dy") }
        guard let dx = parseDouble(args[0]) else { return .failure("\(command) dx invalid") }
        guard let dy = parseDouble(args[1]) else { return .failure("\(command) dy invalid") }
        return .success(token: token, command: make(dx, dy), legacy: legacy, sessionID: sessionID, sequence: sequence)
    }

    private static func tokenize(_ line: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        for character in line {
            if character == "\"" {
                inQuote.toggle()
                continue
            }
            if character.isWhitespace, !inQuote {
                if !current.isEmpty {
                    parts.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func unquote(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\"") { text.removeFirst() }
        if text.hasSuffix("\"") { text.removeLast() }
        return text
    }

    private static func looksLikeCommand(_ value: String) -> Bool {
        [
            "PING", "PONG", "MOVE", "CLICK", "DOUBLE_CLICK", "RIGHT_CLICK", "SCROLL", "MOUSE_DOWN", "MOUSE_UP",
            "RELEASE_ALL", "HEARTBEAT", "HEARTBEAT_ACK", "HELLO", "HELLO_ACK", "PAIR", "PAIR_ACK",
            "PAIR_REQUEST", "PAIR_DECISION", "KEY_DOWN", "KEY_UP", "TYPE", "SYSTEM", "MEDIA", "PRESENTATION",
            "PINCH", "ZOOM", "OPEN_APP", "OPEN_URL", "SHORTCUT", "REQUEST_APP_LIST", "APP_LIST_BEGIN",
            "APP_ENTRY", "APP_LIST_END", "LASER", "LASER_VISIBLE", "CONTROLLER", "REVOKE"
        ].contains(value.uppercased())
    }
}

enum RemoteEnvelope {
    static func encode(token: String, command: RemoteCommand) -> Data {
        RemotePacket.encodeV1(token: token, command: command)
    }

    static func decode(_ raw: String) -> (token: String, command: RemoteCommand)? {
        if case .success(let token, let command, _, _, _) = RemotePacket.parse(raw) {
            return (token, command)
        }
        return nil
    }
}

struct SequenceGate {
    private(set) var lastAccepted: UInt64 = 0
    private(set) var droppedStale = 0

    mutating func shouldAccept(_ sequence: UInt64?) -> Bool {
        guard let sequence else { return true }
        if sequence <= lastAccepted {
            droppedStale += 1
            return false
        }
        lastAccepted = sequence
        return true
    }

    mutating func reset() {
        lastAccepted = 0
    }

    static func runSelfChecks() {
        var gate = SequenceGate()
        precondition(gate.shouldAccept(100))
        precondition(gate.shouldAccept(101))
        precondition(gate.shouldAccept(103))
        precondition(gate.shouldAccept(102) == false)
        precondition(gate.droppedStale == 1)
    }
}
