import Foundation

@MainActor
extension DesktopSession {
    private static let clipboardPasteTargetTitles: Set<String> = [
        "Notes",
        "Documents",
        "Sheets",
        "Browser",
        "ChatGPT",
        "YouTube"
    ]

    /// Clipboard is a normal desktop window, so opening or clicking it makes it
    /// frontmost. Paste must target the immediately previous visible window only;
    /// skipping an unsupported app could unexpectedly inject text into an older
    /// editor that the user did not intend to target.
    var clipboardPasteDestination: DesktopWindow? {
        guard activeWindow?.title == "Clipboard",
              let clipboardID = activeWindowID,
              let clipboardIndex = windows.lastIndex(where: { $0.id == clipboardID }) else { return nil }

        let previousVisible = windows[..<clipboardIndex].reversed().first { !$0.isMinimized }
        guard let previousVisible,
              Self.clipboardPasteTargetTitles.contains(previousVisible.title) else { return nil }
        return previousVisible
    }

    var canPasteClipboardIntoPreviousApp: Bool {
        clipboardPasteDestination != nil
    }

    @discardableResult
    func pasteClipboardItemIntoPreviousApp(_ text: String) -> Bool {
        guard !text.isEmpty,
              let destination = clipboardPasteDestination else { return false }

        // Bring the intended editor/web app forward first, then reuse the same
        // app-specific typing route used by phone/hardware keyboard input. This
        // preserves Notes/Documents/Sheets focus semantics and WebView activeElement
        // behavior without inventing a second clipboard-only input pipeline.
        restoreAndActivate(destination.id)
        typeIntoActiveDesktopField(text)
        return true
    }
}
