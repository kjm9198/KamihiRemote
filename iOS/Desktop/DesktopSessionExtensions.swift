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
        if let topID = topWindow(at: cursor) {
            activate(topID)
            primaryClick()
            clickWebContentAtCursor()
        } else if cursor.y > 0.88 {
            primaryClick()
        }
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

    public func scrollActiveWindow(deltaY: CGFloat) {
        scrollActiveWebView(deltaY: deltaY)
    }

    public func goBackInActiveBrowser() {
        browserBack()
    }

    public func goForwardInActiveBrowser() {
        browserForward()
    }
}
