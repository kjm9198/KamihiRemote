import SwiftUI

/// Convenience and bridging extensions for DesktopSession.
@MainActor
extension DesktopSession {
    public var activeWindow: DesktopWindow? {
        windows.first(where: { $0.id == activeWindowID })
    }

    public var isDraggingWindow: Bool {
        hasActiveWindowDrag
    }

    public var isResizingWindow: Bool {
        hasActiveWindowResize
    }

    public func clickAtCursor() {
        guard let topID = topWindow(at: cursor),
              let window = windows.first(where: { $0.id == topID }) else {
            wantsPhoneKeyboard = false
            return
        }

        let frame = effectiveFrame(for: window)

        if let action = DesktopWindowChrome.action(at: cursor, in: frame) {
            wantsPhoneKeyboard = false
            activate(topID)
            primaryClick()
            switch action {
            case .minimize:
                minimize(topID)
            case .maximizeRestore:
                toggleMaximize(topID)
            case .close:
                close(topID)
            }
            return
        }

        activate(topID)
        primaryClick()

        // Native text apps use the phone keyboard as their explicit editor.
        if window.title == "Notes" || window.title == "Documents" {
            wantsPhoneKeyboard = true
            return
        }

        guard let point = webContentPoint(at: cursor, in: frame) else {
            wantsPhoneKeyboard = false
            return
        }

        DesktopWebInputRegistry.shared.click(
            key: window.title,
            x: point.x,
            y: point.y
        ) { [weak self] editable in
            self?.wantsPhoneKeyboard = editable
        }
    }

    /// New-registry secondary click. Kept separately from the older compatibility
    /// method in DesktopProductivityMode so legacy code can remain untouched.
    public func contextClickAtCursorUsingRegistry() {
        guard let window = topWindowForInput(at: cursor),
              window.title != "Notes",
              window.title != "Documents",
              let point = webContentPoint(at: cursor, in: effectiveFrame(for: window)) else { return }

        wantsPhoneKeyboard = false
        activate(window.id)
        DesktopWebInputRegistry.shared.contextClick(
            key: window.title,
            x: point.x,
            y: point.y
        )
    }

    @discardableResult
    public func beginWindowDrag() -> Bool {
        beginPrimaryDragIfPossible()
    }

    public func updateWindowDrag(delta: CGSize) {
        updatePrimaryDrag(delta: delta)
    }

    public func endWindowDrag() {
        endPrimaryDrag()
    }

    @discardableResult
    public func beginPointerResize() -> Bool {
        beginWindowResizeIfPossible()
    }

    public func updatePointerResize(delta: CGSize) {
        updateWindowResize(delta: delta)
    }

    public func endPointerResize() {
        endWindowResize()
    }

    public func cancelPointerManipulation() {
        cancelWindowManipulation()
    }

    /// Two-axis scrolling uses the same gain and direction rules on both axes.
    /// Pages without horizontal overflow simply clamp X to their valid range.
    public func scrollActiveWindow(deltaX: CGFloat, deltaY: CGFloat) {
        guard let key = activeWindow?.title,
              key != "Notes",
              key != "Documents" else { return }
        DesktopWebInputRegistry.shared.scroll(key: key, deltaX: deltaX, deltaY: deltaY)
    }

    /// Compatibility overload for older call sites and deterministic tests.
    public func scrollActiveWindow(deltaY: CGFloat) {
        scrollActiveWindow(deltaX: 0, deltaY: deltaY)
    }

    public func typeIntoActiveDesktopField(_ text: String) {
        guard !text.isEmpty else { return }
        switch activeWindow?.title {
        case "Notes":
            DesktopNotesStore.shared.appendToActiveBody(text)
            return
        case "Documents":
            DesktopDocumentsStore.shared.appendToActiveBody(text)
            return
        default:
            break
        }
        guard let key = activeWindow?.title else { return }
        DesktopWebInputRegistry.shared.type(key: key, text: text)
    }

    public func deleteBackwardInActiveDesktopField() {
        switch activeWindow?.title {
        case "Notes":
            DesktopNotesStore.shared.deleteBackwardFromActiveBody()
            return
        case "Documents":
            DesktopDocumentsStore.shared.deleteBackwardFromActiveBody()
            return
        default:
            break
        }
        guard let key = activeWindow?.title else { return }
        DesktopWebInputRegistry.shared.deleteBackward(key: key)
    }

    public func pressEnterInActiveDesktopField() {
        switch activeWindow?.title {
        case "Notes":
            DesktopNotesStore.shared.insertNewlineIntoActiveBody()
            return
        case "Documents":
            DesktopDocumentsStore.shared.insertNewlineIntoActiveBody()
            return
        default:
            break
        }
        guard let key = activeWindow?.title else { return }
        DesktopWebInputRegistry.shared.pressEnter(key: key)
    }

    public func dismissPhoneKeyboardRequest() {
        wantsPhoneKeyboard = false
    }

    public func goBackInActiveBrowser() {
        guard let key = activeWindow?.title else { return }
        DesktopWebInputRegistry.shared.goBack(key: key)
    }

    public func goForwardInActiveBrowser() {
        guard let key = activeWindow?.title else { return }
        DesktopWebInputRegistry.shared.goForward(key: key)
    }

    private func topWindowForInput(at point: CGPoint) -> DesktopWindow? {
        windows.reversed().first(where: {
            !$0.isMinimized && effectiveFrame(for: $0).contains(point)
        })
    }

    private func webContentPoint(at point: CGPoint, in frame: CGRect) -> CGPoint? {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        let contentHeight = frame.maxY - contentTop
        guard frame.width > 0,
              contentHeight > 0,
              point.y > contentTop,
              point.y <= frame.maxY else { return nil }

        return CGPoint(
            x: min(max((point.x - frame.minX) / frame.width, 0), 1),
            y: min(max((point.y - contentTop) / contentHeight, 0), 1)
        )
    }
}
