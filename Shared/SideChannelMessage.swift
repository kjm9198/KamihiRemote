import Foundation

enum SideChannelMessage {
    enum Parsed: Equatable {
        case actionAck(kind: String, payload: String, success: Bool)
        case focusSnapshot(text: String, editable: Bool)
    }

    static let focusSnapshotShortcut = "__kamihi_focus_snapshot__"

    static func actionAck(kind: String, payload: String, success: Bool) -> String {
        "KAMIHI_ACTION|\(kind)|\(success ? "1" : "0")|\(encode(payload))"
    }

    static func focusSnapshot(text: String, editable: Bool) -> String {
        "KAMIHI_FOCUS|\(editable ? "1" : "0")|\(encode(text))"
    }

    static func parse(_ value: String) -> Parsed? {
        if value.hasPrefix("KAMIHI_ACTION|") {
            let parts = value.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 4,
                  let payload = decode(String(parts[3]))
            else { return nil }
            return .actionAck(
                kind: String(parts[1]),
                payload: payload,
                success: parts[2] == "1"
            )
        }

        if value.hasPrefix("KAMIHI_FOCUS|") {
            let parts = value.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 3,
                  let text = decode(String(parts[2]))
            else { return nil }
            return .focusSnapshot(text: text, editable: parts[1] == "1")
        }

        return nil
    }

    private static func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }

    private static func decode(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
