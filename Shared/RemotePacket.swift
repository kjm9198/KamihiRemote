import Foundation

enum RemotePacketResult: Equatable {
    case success(token: String, command: RemoteCommand, legacy: Bool)
    case failure(String)
}

enum RemotePacket {
    static func parse(_ raw: String) -> RemotePacketResult {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return .failure("empty packet") }

        var parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !parts.isEmpty else { return .failure("empty packet") }

        var legacy = false
        if looksLikeCommand(parts[0]), parts.count >= 2, PairingSecret.isValid(parts[1]) {
            legacy = true
            let command = parts.remove(at: 0)
            let token = parts.remove(at: 0)
            parts.insert(contentsOf: [token, command], at: 0)
        }

        guard parts.count >= 2 else { return .failure("missing command") }

        let token = parts[0]
        let command = parts[1].uppercased()
        let args = Array(parts.dropFirst(2))

        switch command {
        case "PING":
            return .success(token: token, command: .ping, legacy: legacy)
        case "PONG":
            let name = args.joined(separator: " ")
            return .success(token: token, command: .pong(hostName: name.isEmpty ? "Mac" : name), legacy: legacy)
        case "MOVE":
            return parseVector(token: token, command: "MOVE", args: args, legacy: legacy) { .move(dx: $0, dy: $1) }
        case "CLICK":
            return .success(token: token, command: .click, legacy: legacy)
        case "RIGHT_CLICK":
            return .success(token: token, command: .rightClick, legacy: legacy)
        case "SCROLL":
            return parseVector(token: token, command: "SCROLL", args: args, legacy: legacy) { .scroll(dx: $0, dy: $1) }
        case "MOUSE_DOWN":
            return .success(token: token, command: .mouseDown, legacy: legacy)
        case "MOUSE_UP":
            return .success(token: token, command: .mouseUp, legacy: legacy)
        default:
            return .failure("unknown command \"\(command)\"")
        }
    }

    static func parseDouble(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    static func formatCoord(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    @discardableResult
    static func runSelfChecks() -> Bool {
        func coordsMatch(_ a: Double, _ b: Double) -> Bool {
            abs(a - b) < 0.000001
        }
        func expectSuccess(_ raw: String, token expectedToken: String, _ expected: RemoteCommand, legacy expectedLegacy: Bool = false) {
            switch parse(raw) {
            case .success(let token, let command, let legacy):
                precondition(token == expectedToken, "Auth mismatch for \(raw): \(token)")
                precondition(legacy == expectedLegacy, "Legacy flag mismatch for \(raw)")
                switch (command, expected) {
                case (.ping, .ping), (.click, .click), (.rightClick, .rightClick), (.mouseDown, .mouseDown), (.mouseUp, .mouseUp):
                    break
                case let (.move(dx, dy), .move(ex, ey)), let (.scroll(dx, dy), .scroll(ex, ey)):
                    precondition(coordsMatch(dx, ex) && coordsMatch(dy, ey), "Vector mismatch for \(raw): \(dx),\(dy)")
                case let (.pong(name), .pong(expectedName)):
                    precondition(name == expectedName, "PONG mismatch for \(raw)")
                default:
                    preconditionFailure("Unexpected parse for \(raw): \(command)")
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
        expectSuccess("MOVE 163158 1.289 0.645", token: "163158", .move(dx: 1.289, dy: 0.645), legacy: true)

        if case .success(let token, let command, _) = parse("000000 MOVE 1 2") {
            precondition(token == "000000")
            guard case .move = command else { preconditionFailure("bad pairing code still parses command") }
        } else {
            preconditionFailure("wrong pairing code should still decode")
        }
        guard case .failure(let empty) = parse("") else {
            preconditionFailure("empty packet should fail")
        }
        precondition(empty == "empty packet")
        guard case .failure(let missingCommand) = parse("163158") else {
            preconditionFailure("token-only packet should fail")
        }
        precondition(missingCommand == "missing command")
        guard case .failure(let unknown) = parse("163158 JUMP 1 2") else {
            preconditionFailure("unknown command should fail")
        }
        precondition(unknown.contains("unknown command"))
        guard case .failure(let missingDx) = parse("163158 MOVE") else {
            preconditionFailure("MOVE without args should fail")
        }
        precondition(missingDx == "MOVE missing dx")
        guard case .failure(let missingDy) = parse("163158 MOVE 1.2") else {
            preconditionFailure("MOVE without dy should fail")
        }
        precondition(missingDy == "MOVE missing dy")
        guard case .failure(let invalidDx) = parse("163158 MOVE foo 0.5") else {
            preconditionFailure("invalid MOVE dx should fail")
        }
        precondition(invalidDx == "MOVE dx invalid")
        guard case .failure(let invalidDy) = parse("163158 MOVE 0.5 bar") else {
            preconditionFailure("invalid MOVE dy should fail")
        }
        precondition(invalidDy == "MOVE dy invalid")
        NSLog("Kamihi parser self-checks passed")
        return true
    }

    private static func parseVector(
        token: String,
        command: String,
        args: [String],
        legacy: Bool,
        make: (Double, Double) -> RemoteCommand
    ) -> RemotePacketResult {
        guard args.count >= 1 else { return .failure("\(command) missing dx") }
        guard args.count >= 2 else { return .failure("\(command) missing dy") }
        guard let dx = parseDouble(args[0]) else { return .failure("\(command) dx invalid") }
        guard let dy = parseDouble(args[1]) else { return .failure("\(command) dy invalid") }
        return .success(token: token, command: make(dx, dy), legacy: legacy)
    }

    private static func looksLikeCommand(_ value: String) -> Bool {
        ["PING", "PONG", "MOVE", "CLICK", "RIGHT_CLICK", "SCROLL", "MOUSE_DOWN", "MOUSE_UP"]
            .contains(value.uppercased())
    }
}
