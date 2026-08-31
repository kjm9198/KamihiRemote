import SwiftUI

/// Convenience and bridging extensions for DesktopSession.
@MainActor
extension DesktopSession {
    public var activeWindow: DesktopWindow? {
        windows.first(where: { $0.id == activeWindowID })
    }

    public var isDraggingWindow: Bool {
        topWindow(at: cursor) != nil
    }

    public func clickAtCursor() {
        if let topID = topWindow(at: cursor) {
            activate(topID)
            clickWebContentAtCursor()
        } else if cursor.y > 0.88 {
            // Clicked on dock area
            openBrowser()
        }
    }

    public func beginWindowDrag() {
        beginPrimaryDrag()
    }

    public func endWindowDrag() {
        if let target = WindowSnapEngine.evaluateSnapIntent(cursor: cursor),
           let activeID = activeWindowID,
           let index = windows.firstIndex(where: { $0.id == activeID }) {
            windows[index].isMaximized = (target == .maximize)
            windows[index].normalizedFrame = WindowSnapEngine.frame(for: target)
        }
        endPrimaryDrag()
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
