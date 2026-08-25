import ApplicationServices
import Foundation

enum FocusedTextReader {
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
            return (.value, text)
        }

        if isTextEditable(roleName: roleName, settable: settable.boolValue) {
            return (.value, "")
        }

        return (.unavailable, "Live text unavailable here")
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
