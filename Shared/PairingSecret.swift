import Foundation

enum PairingSecret {
    static let length = 6

    static func generate() -> String {
        (0..<length).map { _ in String(Int.random(in: 0...9)) }.joined()
    }

    static func isValid(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == length && trimmed.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
    }

    static func matches(_ left: String, _ right: String) -> Bool {
        let a = Array(left.utf8)
        let b = Array(right.utf8)
        guard a.count == b.count, a.count == length else { return false }
        var difference: UInt8 = 0
        for index in 0..<a.count {
            difference |= a[index] ^ b[index]
        }
        return difference == 0
    }
}

enum RemoteEnvelope {
    static func encode(token: String, command: RemoteCommand) -> Data {
        Data("\(token) \(command.wire)\n".utf8)
    }

    static func decode(_ raw: String) -> (token: String, command: RemoteCommand)? {
        if case .success(let token, let command, _) = RemotePacket.parse(raw) {
            return (token, command)
        }
        return nil
    }
}
