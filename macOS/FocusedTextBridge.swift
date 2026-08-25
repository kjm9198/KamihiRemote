import ApplicationServices
import Foundation

struct FocusedTextSnapshot: Equatable {
    var text: String
    var editable: Bool
}

enum FocusedTextBridge {
    private static let maxCharacters = 20_000

    static func snapshot() -> FocusedTextSnapshot {
        guard AXIsProcessTrusted() else {
            return FocusedTextSnapshot(text: "", editable: false)
        }

        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue
        else {
            return FocusedTextSnapshot(text: "", editable: false)
        }

        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return FocusedTextSnapshot(text: "", editable: false)
        }
        let element = focusedValue as! AXUIElement

        if isSecure(element) {
            return FocusedTextSnapshot(text: "", editable: false)
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )

        var editable = DarwinBoolean(false)
        _ = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &editable
        )

        guard result == .success else {
            return FocusedTextSnapshot(text: "", editable: editable.boolValue)
        }

        let text: String
        if let string = value as? String {
            text = string
        } else if let attributed = value as? NSAttributedString {
            text = attributed.string
        } else {
            text = ""
        }

        return FocusedTextSnapshot(
            text: String(text.prefix(maxCharacters)),
            editable: editable.boolValue
        )
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        var subroleValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        _ = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)

        let role = (roleValue as? String)?.lowercased() ?? ""
        let subrole = (subroleValue as? String)?.lowercased() ?? ""
        return role.contains("secure") || subrole.contains("secure") || subrole.contains("password")
    }
}
