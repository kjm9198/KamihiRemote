import Foundation

@MainActor
extension RemoteSession {
    /// Explicitly asks the paired Mac for the current focused text so a vibe prompt can use it as context.
    /// This is user-triggered only; KamihiRemote does not poll or capture focused text in the background.
    func captureFocusedTextForVibe(maxCharacters: Int = 4_000) async -> String? {
        guard isConnected else {
            flashAction("Mac context\nNot connected", success: false)
            return nil
        }

        let keyboardWasShown = showsKeyboard
        focusedTextStatus = .unavailable
        focusedTextValue = ""
        requestFocusedText()

        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 100_000_000)

            // requestFocusedText is also used by the keyboard workflow, so the normal response
            // may present the keyboard. Context capture restores the caller's previous UI state.
            if keyboardWasShown == false {
                showsKeyboard = false
            }

            switch focusedTextStatus {
            case .secure:
                flashAction("Mac context\nSecure field hidden", success: false)
                return nil
            case .value:
                let clean = focusedTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard clean.isEmpty == false else { continue }
                return Self.boundedVibeContext(clean, maxCharacters: maxCharacters)
            case .unavailable:
                // Keep polling briefly because the request starts in this state too.
                continue
            }
        }

        if keyboardWasShown == false {
            showsKeyboard = false
        }
        flashAction("Mac context\nNo readable focused text", success: false)
        return nil
    }

    private static func boundedVibeContext(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, text.count > maxCharacters else { return text }

        // Preserve both the beginning (definitions/context) and the end (often the newest error/log lines).
        let headCount = maxCharacters / 2
        let tailCount = maxCharacters - headCount
        let head = String(text.prefix(headCount))
        let tail = String(text.suffix(tailCount))
        return head + "\n\n… [Mac context truncated] …\n\n" + tail
    }
}
