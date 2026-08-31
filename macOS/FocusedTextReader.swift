import ApplicationServices
import Foundation

enum FocusedTextReader {
    // Keep focused-text responses comfortably below the 64 KiB reliable-frame limit.
    // RemoteCommand quoting can roughly double ASCII-heavy text (slashes/newlines), so
    // cap the raw UTF-8 payload at 24 KiB and preserve the document suffix. CodeKey's
    // current live-edit model is end-focused, making the suffix the most useful slice.
    private static let maxSnapshotBytes = 24 * 1024

    static func snapshot() -> (status: FocusedTextStatus, value: String) {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedStatus == .success, let element = focused else {
            return (.unavailable, "Live text unavailable here")
        }
        let ui = unsafeBitCast(element, to: AXUIElement.self)
        if isSecure(ui) {
            return (.secure, "")
        }

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(ui, kAXRoleAttribute as CFString, &role)
        let roleName = (role as? String) ?? ""

        var settable: DarwinBoolean = false
        _ = AXUIElementIsAttributeSettable(ui, kAXValueAttribute as CFString, &settable)

        var value: CFTypeRef?
        let valueStatus = AXUIElementCopyAttributeValue(ui, kAXValueAttribute as CFString, &value)
        if valueStatus == .success, let raw = value, CFGetTypeID(raw) == CFStringGetTypeID() {
            let text = raw as! String

            // CodeKey can currently mirror/delete only from the end of the focused value.
            // If Accessibility tells us the caret or selection is elsewhere, do not send a
            // misleading baseline to the phone: that could make a phone-side backspace delete
            // text at the Mac caret while the UI appears to be deleting the document suffix.
            // Falling back to "unavailable" keeps direct typing usable without pretending the
            // mirrored value is safely editable. A future selection-aware protocol can lift this.
            if let selection = selectedTextRange(ui), selectionTouchesEnd(selection, text: text) == false {
                return (.unavailable, "Move the Mac cursor to the end to edit mirrored text safely")
            }

            return (.value, boundedSnapshot(text))
        }

        if isTextEditable(roleName: roleName, settable: settable.boolValue) {
            return (.value, "")
        }

        return (.unavailable, "Live text unavailable here")
    }

    private static func selectedTextRange(_ element: AXUIElement) -> CFRange? {
        var rawRange: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rawRange
        )
        guard status == .success,
              let rawRange,
              CFGetTypeID(rawRange) == AXValueGetTypeID() else {
            return nil
        }

        let value = unsafeBitCast(rawRange, to: AXValue.self)
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else { return nil }
        guard range.location >= 0, range.length >= 0 else { return nil }
        return range
    }

    private static func selectionTouchesEnd(_ range: CFRange, text: String) -> Bool {
        let utf16Length = (text as NSString).length
        let end = range.location + range.length
        return end == utf16Length
    }

    private static func boundedSnapshot(_ text: String) -> String {
        guard text.utf8.count > maxSnapshotBytes else { return text }

        var start = text.endIndex
        var bytes = 0
        while start > text.startIndex {
            let previous = text.index(before: start)
            let characterBytes = text[previous..<start].utf8.count
            guard bytes + characterBytes <= maxSnapshotBytes else { break }
            bytes += characterBytes
            start = previous
        }

        let suffix = String(text[start...])
        NSLog(
            "Kamihi focused text truncated from %d to %d UTF-8 bytes",
            text.utf8.count,
            suffix.utf8.count
        )
        return suffix
    }

    private static func isTextEditable(roleName: String, settable: Bool) -> Bool {
        if settable { return true }
        let editableRoles = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox", "AXWebArea"]
        return editableRoles.contains(roleName)
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleName = (role as? String) ?? ""
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        let subroleName = (subrole as? String) ?? ""
        if roleName == "AXSecureTextField" { return true }
        if subroleName.lowercased().contains("secure") || subroleName.lowercased().contains("password") { return true }
        if roleName.lowercased().contains("password") { return true }
        return false
    }
}
