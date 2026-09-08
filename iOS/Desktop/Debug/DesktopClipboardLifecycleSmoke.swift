import Foundation
import OSLog
import UIKit

#if DEBUG
@MainActor
enum DesktopClipboardLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "ClipboardSmoke")
    static let launchArgument = "-KamihiClipboardLifecycleSmoke"
    static let successMarker = "KAMIHI_CLIPBOARD_LIFECYCLE_OK"

    @discardableResult
    static func run(on desktop: DesktopSession) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return true }

        for title in ["Clipboard", "Notes", "Calculator"] {
            for window in desktop.windows.filter({ $0.title == title }) {
                desktop.close(window.id)
            }
        }

        let notes = DesktopNotesStore.shared
        if notes.activeNoteID == nil { notes.createNewNote() }
        notes.focus(.body)
        let originalBody = notes.activeNote?.body ?? ""
        let payload = " Kamihi clipboard smoke"

        let notesID = desktop.openProductivityApp(
            "Notes",
            frame: CGRect(x: 0.08, y: 0.10, width: 0.52, height: 0.70)
        )
        guard assertWindow(desktop, id: notesID, title: "Notes", minimized: false, maximized: false, active: true, step: "open-notes") else { return false }

        let clipboardID = desktop.openProductivityApp(
            "Clipboard",
            frame: CGRect(x: 0.42, y: 0.16, width: 0.48, height: 0.62)
        )
        guard assertWindow(desktop, id: clipboardID, title: "Clipboard", minimized: false, maximized: false, active: true, step: "open-clipboard") else { return false }
        guard desktop.canPasteClipboardIntoPreviousApp else {
            return fail("notes-target", "Paste was disabled with Notes immediately behind Clipboard")
        }

        guard desktop.pasteClipboardItemIntoPreviousApp(payload) else {
            return fail("notes-paste", "Paste routing rejected a valid Notes destination")
        }
        guard desktop.activeWindowID == notesID else {
            return fail("notes-focus", "Paste did not restore Notes as the frontmost window")
        }
        guard notes.activeNote?.body == originalBody + payload else {
            return fail("notes-content", "Notes did not receive exactly one Clipboard insertion")
        }

        desktop.restoreAndActivate(clipboardID)
        desktop.minimize(clipboardID)
        guard assertWindow(desktop, id: clipboardID, title: "Clipboard", minimized: true, maximized: false, active: false, step: "minimize") else { return false }
        desktop.restoreAndActivate(clipboardID)
        guard assertWindow(desktop, id: clipboardID, title: "Clipboard", minimized: false, maximized: false, active: true, step: "restore") else { return false }
        desktop.toggleMaximize(clipboardID)
        guard assertWindow(desktop, id: clipboardID, title: "Clipboard", minimized: false, maximized: true, active: true, step: "maximize") else { return false }
        desktop.toggleMaximize(clipboardID)
        guard assertWindow(desktop, id: clipboardID, title: "Clipboard", minimized: false, maximized: false, active: true, step: "restore-maximized") else { return false }

        desktop.close(clipboardID)
        guard !desktop.windows.contains(where: { $0.id == clipboardID }), desktop.activeWindowID != clipboardID else {
            return fail("close", "Clipboard remained in the window list or retained focus after X/close")
        }

        let calculatorID = desktop.openProductivityApp(
            "Calculator",
            frame: CGRect(x: 0.10, y: 0.14, width: 0.38, height: 0.62)
        )
        let unsupportedClipboardID = desktop.openProductivityApp(
            "Clipboard",
            frame: CGRect(x: 0.46, y: 0.18, width: 0.46, height: 0.58)
        )
        guard desktop.activeWindowID == unsupportedClipboardID else {
            return fail("unsupported-focus", "Clipboard was not frontmost for unsupported-target test")
        }
        guard desktop.windows.first(where: { $0.id == calculatorID })?.isMinimized == false else {
            return fail("unsupported-target", "Calculator unexpectedly unavailable behind Clipboard")
        }
        guard !desktop.canPasteClipboardIntoPreviousApp,
              desktop.clipboardPasteDestination == nil else {
            return fail("unsupported-target", "Paste remained enabled with Calculator immediately behind Clipboard")
        }
        guard !desktop.pasteClipboardItemIntoPreviousApp("must not paste") else {
            return fail("unsupported-paste", "Clipboard accepted paste into unsupported adjacent app")
        }
        guard desktop.activeWindowID == unsupportedClipboardID else {
            return fail("unsupported-focus", "Rejected Paste unexpectedly changed focus")
        }

        logger.notice("\(successMarker, privacy: .public)")
        print(successMarker)
        return true
    }

    private static func assertWindow(
        _ desktop: DesktopSession,
        id: UUID,
        title: String,
        minimized: Bool,
        maximized: Bool,
        active: Bool,
        step: String
    ) -> Bool {
        guard let window = desktop.windows.first(where: { $0.id == id }) else {
            return fail(step, "window is missing")
        }
        guard window.title == title else { return fail(step, "wrong window title: \(window.title)") }
        guard window.isMinimized == minimized else { return fail(step, "minimized ownership mismatch") }
        guard window.isMaximized == maximized else { return fail(step, "maximized ownership mismatch") }
        guard (desktop.activeWindowID == id) == active else { return fail(step, "active ownership mismatch") }
        return true
    }

    private static func fail(_ step: String, _ message: String) -> Bool {
        logger.error("KAMIHI_CLIPBOARD_LIFECYCLE_FAIL [\(step, privacy: .public)] \(message, privacy: .public)")
        assertionFailure("Clipboard lifecycle smoke failed at \(step): \(message)")
        return false
    }
}
#endif
