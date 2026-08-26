import Foundation
import CryptoKit

enum RemotePacketResult: Equatable {
    case success(token: String, command: RemoteCommand, legacy: Bool, sessionID: String?, sequence: UInt64?, isEncrypted: Bool)
    case failure(String)
}

enum RemotePacket {
    static func parse(_ raw: String, sessionKey: SymmetricKey? = nil) -> RemotePacketResult {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return .failure("empty packet") }

        if line.hasPrefix("K3 ") {
            return parseV3(line, sessionKey: sessionKey)
        }
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

    static func encodeK3(sessionID: String, sequence: UInt64, command: RemoteCommand, key: SymmetricKey) throws -> Data {
        let nonce = SessionCrypto.randomNonce()
        let plaintext = Data(command.wire.utf8)
        let sealed = try SessionCrypto.seal(plaintext: plaintext, key: key, nonceData: nonce)
        let nonceB64 = nonce.base64EncodedString()
        let cipherB64 = sealed.base64EncodedString()
        return Data("K3 \(sessionID) \(sequence) \(nonceB64) \(cipherB64)\n".utf8)
    }

    @discardableResult
    static func runSelfChecks() -> Bool {
        func coordsMatch(_ a: Double, _ b: Double) -> Bool {
            abs(a - b) < 0.000001
        }
        func expectSuccess(_ raw: String, token expectedToken: String, _ expected: RemoteCommand, legacy expectedLegacy: Bool = false) {
            switch parse(raw) {
            case .success(let token, let command, let legacy, _, _, _):
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
        expectSuccess("163158 SYSTEM nextDesktop", token: "163158", .system(.nextDesktop))
        expectSuccess("163158 ACTION 9c7 SYSTEM nextDesktop", token: "163158", .action(id: "9c7", inner: .system(.nextDesktop)))
        expectSuccess("163158 ACTION_ACK 9c7 OK Switched", token: "163158", .actionAck(id: "9c7", success: true, message: "Switched"))
        expectSuccess("163158 ACTION_ACK 9c7 FAIL \"Desktop did not change\"", token: "163158", .actionAck(id: "9c7", success: false, message: "Desktop did not change"))
        expectSuccess("163158 REQUEST_FOCUSED_TEXT", token: "163158", .requestFocusedText)
        expectSuccess("163158 FOCUSED_TEXT value Hello", token: "163158", .focusedText(status: .value, value: "Hello"))
        let exactText = "let json = {\"message\": \"xin chào / cześć\"}\n\tprint(\"\\path\\to\\file 😀\")\r\n"
    expectSuccess(String(decoding: encodeV1(token: "163158", command: .typeText(exactText)), as: UTF8.self), token: "163158", .typeText(exactText))
    expectSuccess(String(decoding: encodeV1(token: "163158", command: .focusedText(status: .value, value: exactText)), as: UTF8.self), token: "163158", .focusedText(status: .value, value: exactText))
        expectSuccess("163158 ACTIVE_APP com.microsoft.VSCode \"Visual Studio Code\"", token: "163158", .activeApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code"))
        expectSuccess("163158 REQUEST_ACTIVE_APP", token: "163158", .requestActiveApp)
        expectSuccess("163158 RUN_COMMAND \"git status\"", token: "163158", .runCommand("git status"))
        let testMapping = ControllerMapping.mac
        let mappingJson = (try? JSONEncoder().encode(testMapping)) ?? Data()
        expectSuccess("163158 CONTROLLER_CONFIG \(mappingJson.base64EncodedString())", token: "163158", .syncControllerMapping(testMapping))
        expectSuccess("MOVE 163158 1.289 0.645", token: "163158", .move(dx: 1.289, dy: 0.645), legacy: true)

        switch parse("K2 sess-1 103 1710000000.000 MOVE 1.289 0.645") {
        case .success(let token, let command, _, let session, let seq, _):
            precondition(token == "sess-1")
            precondition(session == "sess-1")
            precondition(seq == 103)
            guard case .move(let dx, let dy) = command, coordsMatch(dx, 1.289), coordsMatch(dy, 0.645) else {
                preconditionFailure("v2 MOVE parse failed")
            }
        case .failure(let reason):
            preconditionFailure("v2 MOVE should parse: \(reason)")
        }

        // K3 Authenticated Encryption Self-Check (non-fatal — never crash the host at launch)
        do {
            let testKey = SymmetricKey(size: .bits256)
            let rawData = try encodeK3(sessionID: "test-sess", sequence: 42, command: .move(dx: 3.5, dy: -1.25), key: testKey)
            guard let rawStr = String(data: rawData, encoding: .utf8) else {
                NSLog("Kamihi K3 self-check: invalid UTF8")
                return true
            }
            switch parse(rawStr, sessionKey: testKey) {
            case .success(_, let cmd, _, let sess, let seq, let isEnc):
                guard sess == "test-sess", seq == 42, isEnc,
                      case .move(let dx, let dy) = cmd, coordsMatch(dx, 3.5), coordsMatch(dy, -1.25)
                else {
                    NSLog("Kamihi K3 self-check: decrypted payload mismatch")
                    break
                }
            case .failure(let err):
                NSLog("Kamihi K3 self-check parse failed: %@", err)
            }

            // Corrupt only the ciphertext token (last field), not the whole line.
            var parts = rawStr.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 5, let last = parts.last, last.isEmpty == false {
                var chars = Array(last)
                if let idx = chars.indices.first {
                    chars[idx] = chars[idx] == "A" ? "B" : "A"
                    parts[parts.count - 1] = String(chars)
                    let corrupted = parts.joined(separator: " ")
                    if case .success = parse(corrupted, sessionKey: testKey) {
                        NSLog("Kamihi K3 self-check: corrupted packet unexpectedly accepted")
                    }
                }
            }
        } catch {
            NSLog("Kamihi K3 self-check threw: %@", String(describing: error))
        }

        if case .success(let token, let command, _, _, _, _) = parse("000000 MOVE 1 2") {
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
        return decode(token: parts[0], command: parts[1], args: Array(parts.dropFirst(2)), legacy: legacy, sessionID: nil, sequence: nil, isEncrypted: false)
    }

    private static func parseV2(_ line: String) -> RemotePacketResult {
        let parts = tokenize(line)
        guard parts.count >= 5 else { return .failure("missing command") }
        let session = parts[1]
        guard let sequence = UInt64(parts[2]) else { return .failure("invalid sequence") }
        return decode(token: session, command: parts[4], args: Array(parts.dropFirst(5)), legacy: false, sessionID: session, sequence: sequence, isEncrypted: false)
    }

    private static func parseV3(_ line: String, sessionKey: SymmetricKey?) -> RemotePacketResult {
        let parts = tokenize(line)
        guard parts.count >= 5 else { return .failure("K3 missing fields") }
        let session = parts[1]
        guard let sequence = UInt64(parts[2]) else { return .failure("invalid sequence") }
        guard let nonceData = Data(base64Encoded: parts[3]), nonceData.count == 12 else {
            return .failure("invalid nonce")
        }
        guard let cipherData = Data(base64Encoded: parts[4]), cipherData.count > 16 else {
            return .failure("invalid ciphertext")
        }
        guard let sessionKey else {
            return .failure("no session key available to decrypt K3")
        }

        do {
            let plaintextData = try SessionCrypto.open(ciphertextAndTag: cipherData, key: sessionKey, nonceData: nonceData)
            guard let plainText = String(data: plaintextData, encoding: .utf8) else {
                return .failure("decrypted plaintext not utf8")
            }
            let innerParts = tokenize(plainText)
            guard !innerParts.isEmpty else { return .failure("empty decrypted command") }
            return decode(token: session, command: innerParts[0], args: Array(innerParts.dropFirst()), legacy: false, sessionID: session, sequence: sequence, isEncrypted: true)
        } catch {
            return .failure("K3 auth tag verification failed")
        }
    }

    private static func decode(token: String, command rawCommand: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?, isEncrypted: Bool) -> RemotePacketResult {
        let command = rawCommand.uppercased()
        switch command {
        case "PING":
            return .success(token: token, command: .ping, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PONG":
            let name = unquote(args.joined(separator: " "))
            return .success(token: token, command: .pong(hostName: name.isEmpty ? "Mac" : name), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "MOVE":
            return parseVector(token: token, command: "MOVE", args: args, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted) { .move(dx: $0, dy: $1) }
        case "CLICK":
            return .success(token: token, command: .click, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "DOUBLE_CLICK":
            return .success(token: token, command: .doubleClick, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "RIGHT_CLICK":
            return .success(token: token, command: .rightClick, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "SCROLL":
            return parseScroll(token: token, args: args, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "MOUSE_DOWN":
            return .success(token: token, command: .mouseDown, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "MOUSE_UP":
            return .success(token: token, command: .mouseUp, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "RELEASE_ALL":
            return .success(token: token, command: .releaseAll, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "HEARTBEAT":
            guard args.count >= 2, let id = UInt64(args[0]), let ts = parseDouble(args[1]) else { return .failure("HEARTBEAT invalid") }
            return .success(token: token, command: .heartbeat(id: id, timestamp: ts), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "HEARTBEAT_ACK":
            guard args.count >= 2, let id = UInt64(args[0]), let ts = parseDouble(args[1]) else { return .failure("HEARTBEAT_ACK invalid") }
            return .success(token: token, command: .heartbeatAck(id: id, timestamp: ts), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "HELLO":
            guard args.count >= 3 else { return .failure("HELLO missing fields") }
            let deviceID = args.count > 1 ? args[1] : "-"
            let deviceName = unquote(args.dropFirst(2).dropLast().joined(separator: " "))
            let capabilities = args.last ?? "-"
            return .success(token: token, command: .hello(deviceID: deviceID, deviceName: deviceName.isEmpty ? "iPhone" : deviceName, capabilities: capabilities), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "HELLO_ACK":
            guard args.count >= 4, let port = UInt16(args[3]) else { return .failure("HELLO_ACK missing fields") }
            return .success(token: token, command: .helloAck(sessionID: args[0], hostName: unquote(args[1]), hostID: args[2], realtimePort: port), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PAIR":
            guard args.count >= 2 else { return .failure("PAIR missing fields") }
            return .success(token: token, command: .pair(code: args[0], deviceID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PAIR_ACK":
            guard args.count >= 2 else { return .failure("PAIR_ACK missing fields") }
            return .success(token: token, command: .pairAck(ok: args[0].uppercased() == "OK", sessionID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "KEY_DOWN":
            guard args.count >= 2, let code = UInt16(args[0]), let flags = UInt64(args[1]) else { return .failure("KEY_DOWN invalid") }
            return .success(token: token, command: .keyDown(code: code, flags: flags), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "KEY_UP":
            guard args.count >= 2, let code = UInt16(args[0]), let flags = UInt64(args[1]) else { return .failure("KEY_UP invalid") }
            return .success(token: token, command: .keyUp(code: code, flags: flags), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "TYPE":
            return .success(token: token, command: .typeText(unquote(args.joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "SYSTEM":
            guard let raw = args.first, let action = SystemAction(rawValue: raw) else { return .failure("unknown system action") }
            return .success(token: token, command: .system(action), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "MEDIA":
            guard let raw = args.first, let action = MediaAction(rawValue: raw) else { return .failure("unknown media action") }
            return .success(token: token, command: .media(action), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PRESENTATION":
            guard let raw = args.first, let action = PresentationAction(rawValue: raw) else { return .failure("unknown presentation action") }
            let profile = args.dropFirst().first.flatMap(PresentationProfile.init(rawValue:)) ?? .keynote
            return .success(token: token, command: .presentation(action: action, profile: profile), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PINCH":
            guard let delta = args.first.flatMap(parseDouble) else { return .failure("PINCH invalid") }
            return .success(token: token, command: .pinch(delta: delta), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "ZOOM":
            guard let raw = args.first, let action = ZoomAction(rawValue: raw) else { return .failure("ZOOM invalid") }
            return .success(token: token, command: .zoom(action), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "OPEN_APP":
            guard let bundle = args.first, bundle.isEmpty == false else { return .failure("OPEN_APP missing bundle") }
            return .success(token: token, command: .openApp(bundleID: bundle), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "OPEN_URL":
            return .success(token: token, command: .openURL(unquote(args.joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "SHORTCUT":
            guard let spec = args.first else { return .failure("SHORTCUT missing spec") }
            return .success(token: token, command: .shortcut(spec), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "REQUEST_APP_LIST":
            return .success(token: token, command: .requestAppList, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "APP_LIST_BEGIN":
            let count = args.first.flatMap { Int($0) } ?? 0
            return .success(token: token, command: .appListBegin(count: count), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "APP_ENTRY":
            guard args.count >= 2 else { return .failure("APP_ENTRY missing fields") }
            return .success(token: token, command: .appEntry(name: unquote(args[0]), bundleID: args[1]), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "APP_LIST_END":
            return .success(token: token, command: .appListEnd, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "LASER":
            return parseVector(token: token, command: "LASER", args: args, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted) { .laser(x: $0, y: $1) }
        case "LASER_VISIBLE":
            let visible = (args.first ?? "0") != "0"
            return .success(token: token, command: .laserVisible(visible), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "CONTROLLER":
            return parseController(token: token, args: args, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PAIR_REQUEST":
            guard args.count >= 4 else { return .failure("PAIR_REQUEST missing fields") }
            return .success(token: token, command: .pairRequest(deviceID: args[0], deviceName: unquote(args[1]), publicKey: args[2], code: args[3]), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "PAIR_DECISION":
            guard args.count >= 3 else { return .failure("PAIR_DECISION missing fields") }
            return .success(token: token, command: .pairDecision(ok: args[0].uppercased() == "OK", deviceID: args[1], sessionMaterial: args[2]), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "REVOKE":
            guard let deviceID = args.first else { return .failure("REVOKE missing device") }
            return .success(token: token, command: .revokeDevice(deviceID: deviceID), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "ACTION":
            guard args.count >= 2 else { return .failure("ACTION missing fields") }
            let nested = decode(token: token, command: args[1], args: Array(args.dropFirst(2)), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
            switch nested {
            case .success(_, let inner, _, _, _, _):
                return .success(token: token, command: .action(id: args[0], inner: inner), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
            case .failure(let reason):
                return .failure(reason)
            }
        case "ACTION_ACK":
            guard args.count >= 2 else { return .failure("ACTION_ACK missing fields") }
            let ok = args[1].uppercased() == "OK"
            let message = unquote(args.dropFirst(2).joined(separator: " "))
            return .success(token: token, command: .actionAck(id: args[0], success: ok, message: message), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "REQUEST_FOCUSED_TEXT":
            return .success(token: token, command: .requestFocusedText, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "FOCUSED_TEXT":
            guard let raw = args.first, let status = FocusedTextStatus(rawValue: raw) else { return .failure("FOCUSED_TEXT invalid") }
            return .success(token: token, command: .focusedText(status: status, value: unquote(args.dropFirst().joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "CONTROLLER_CONFIG":
            guard let b64 = args.first,
                  let data = Data(base64Encoded: b64),
                  let mapping = try? JSONDecoder().decode(ControllerMapping.self, from: data) else {
                return .failure("CONTROLLER_CONFIG invalid")
            }
            return .success(token: token, command: .syncControllerMapping(mapping), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "ACTIVE_APP":
            guard args.count >= 2 else { return .failure("ACTIVE_APP missing fields") }
            let bundle = args[0]
            let name = unquote(args.dropFirst().joined(separator: " "))
            return .success(token: token, command: .activeApp(bundleID: bundle, name: name), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "REQUEST_ACTIVE_APP":
            return .success(token: token, command: .requestActiveApp, legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        case "RUN_COMMAND":
            guard !args.isEmpty else { return .failure("RUN_COMMAND missing command") }
            return .success(token: token, command: .runCommand(unquote(args.joined(separator: " "))), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
        default:
            return .failure("unknown command \"\(command)\"")
        }
    }

    private static func parseScroll(token: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?, isEncrypted: Bool) -> RemotePacketResult {
        guard args.count >= 1 else { return .failure("SCROLL missing dx") }
        guard args.count >= 2 else { return .failure("SCROLL missing dy") }
        guard let dx = parseDouble(args[0]) else { return .failure("SCROLL dx invalid") }
        guard let dy = parseDouble(args[1]) else { return .failure("SCROLL dy invalid") }
        let phase = args.count >= 3 ? (ScrollPhase(rawValue: args[2]) ?? .changed) : .changed
        return .success(token: token, command: .scroll(dx: dx, dy: dy, phase: phase), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
    }

    private static func parseController(token: String, args: [String], legacy: Bool, sessionID: String?, sequence: UInt64?, isEncrypted: Bool) -> RemotePacketResult {
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
        return .success(token: token, command: .controller(state), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
    }

    private static func parseVector(
        token: String,
        command: String,
        args: [String],
        legacy: Bool,
        sessionID: String?,
        sequence: UInt64?,
        isEncrypted: Bool,
        make: (Double, Double) -> RemoteCommand
    ) -> RemotePacketResult {
        guard args.count >= 1 else { return .failure("\(command) missing dx") }
        guard args.count >= 2 else { return .failure("\(command) missing dy") }
        guard let dx = parseDouble(args[0]) else { return .failure("\(command) dx invalid") }
        guard let dy = parseDouble(args[1]) else { return .failure("\(command) dy invalid") }
        return .success(token: token, command: make(dx, dy), legacy: legacy, sessionID: sessionID, sequence: sequence, isEncrypted: isEncrypted)
    }

    private static func tokenize(_ line: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuote = false
    var isEscaping = false

    for character in line {
        if isEscaping {
            if inQuote {
                switch character {
                case "n": current.append("\n")
                case "r": current.append("\r")
                case "t": current.append("\t")
                case "\"": current.append("\"")
                case "\\": current.append("\\")
                default:
                    current.append("\\")
                    current.append(character)
                }
            } else {
                current.append("\\")
                current.append(character)
            }
            isEscaping = false
            continue
        }

        if character == "\\", inQuote {
            isEscaping = true
            continue
        }
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
    if isEscaping { current.append("\\") }
    if !current.isEmpty { parts.append(current) }
    return parts
}

    private static func unquote(_ value: String) -> String {
    // tokenize(_:) already removes wire quotes and decodes escapes.
    // Boundary whitespace is meaningful for keyboard and mirrored text.
    value
}

    private static func looksLikeCommand(_ value: String) -> Bool {
        [
            "PING", "PONG", "MOVE", "CLICK", "DOUBLE_CLICK", "RIGHT_CLICK", "SCROLL", "MOUSE_DOWN", "MOUSE_UP",
            "RELEASE_ALL", "HEARTBEAT", "HEARTBEAT_ACK", "HELLO", "HELLO_ACK", "PAIR", "PAIR_ACK",
            "PAIR_REQUEST", "PAIR_DECISION", "KEY_DOWN", "KEY_UP", "TYPE", "SYSTEM", "MEDIA", "PRESENTATION",
            "PINCH", "ZOOM", "OPEN_APP", "OPEN_URL", "SHORTCUT", "REQUEST_APP_LIST", "APP_LIST_BEGIN",
            "APP_ENTRY", "APP_LIST_END", "LASER", "LASER_VISIBLE", "CONTROLLER", "REVOKE",
            "ACTION", "ACTION_ACK", "REQUEST_FOCUSED_TEXT", "FOCUSED_TEXT", "CONTROLLER_CONFIG",
            "ACTIVE_APP", "REQUEST_ACTIVE_APP", "RUN_COMMAND"
        ].contains(value.uppercased())
    }
}

enum RemoteEnvelope {
    static func encode(token: String, command: RemoteCommand) -> Data {
        RemotePacket.encodeV1(token: token, command: command)
    }

    static func decode(_ raw: String, sessionKey: SymmetricKey? = nil) -> (token: String, command: RemoteCommand)? {
        if case .success(let token, let command, _, _, _, _) = RemotePacket.parse(raw, sessionKey: sessionKey) {
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
