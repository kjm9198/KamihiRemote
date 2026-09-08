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
    /// frontmost. Paste must therefore resolve the most-recent visible editable
    /// app *behind* Clipboard instead of typing into the Clipboard window itself.
    var clipboardPasteDestination: DesktopWindow? {
        windows.reversed().first { window in
            !window.isMinimized &&
            window.title != "Clipboard" &&
            Self.clipboardPasteTargetTitles.contains(window.title)
        }
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
