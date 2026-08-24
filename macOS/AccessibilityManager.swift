import ApplicationServices
import AppKit
import Foundation

final class AccessibilityManager: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        if isTrusted { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
