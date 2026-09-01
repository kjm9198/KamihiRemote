import SwiftUI
import UIKit
import WebKit

@MainActor
final class DesktopSession: ObservableObject {
    static let shared = DesktopSession()

    struct DesktopWindow: Identifiable, Equatable {
        let id: UUID
        var title: String
        var normalizedFrame: CGRect
        var isMinimized: Bool
        var isMaximized: Bool

        init(
            id: UUID = UUID(),
            title: String,
            normalizedFrame: CGRect = CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60),
            isMinimized: Bool = false,
            isMaximized: Bool = false
        ) {
            self.id = id
            self.title = title
            self.normalizedFrame = normalizedFrame
            self.isMinimized = isMinimized
            self.isMaximized = isMaximized
        }
    }

    enum ResizeEdge: String, Equatable {
        case left
        case right
        case top
        case bottom
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    @Published private(set) var isExternalDisplayConnected = false
    @Published var cursor = CGPoint(x: 0.5, y: 0.45)
    @Published var windows: [DesktopWindow] = []
    @Published var activeWindowID: UUID?
    @Published var wantsPhoneKeyboard = false
    @Published private(set) var cursorInteractionState: CursorInteractionState = .defaultState
    @Published private(set) var snapPreviewTarget: WindowSnapEngine.SnapTarget?

    private var dragWindowID: UUID?
    private var dragOffset = CGPoint.zero

    private var resizeWindowID: UUID?
    private var resizeEdge: ResizeEdge?
    private var resizeStartFrame: CGRect = .zero
    private var resizeStartCursor: CGPoint = .zero

    /// Floating frames are retained while a window is snapped/maximized so a
    /// drag away from the edge restores the user's previous size and position.
    private var restoreFrames: [UUID: CGRect] = [:]
    private var snapTargets: [UUID: WindowSnapEngine.SnapTarget] = [:]

    private init() {}

    func externalDisplayDidConnect() {
        isExternalDisplayConnected = true
        // Startup profiles own initial placement. Connecting a cable must never
        // silently launch Browser or any other app.
    }

    func externalDisplayDidDisconnect() {
        isExternalDisplayConnected = false
        wantsPhoneKeyboard = false
        cancelWindowManipulation()
    }

    func openBrowser() {
        if let existing = windows.first(where: { $0.title == "Browser" }) {
            restoreAndActivate(existing.id)
            return
        }

        let window = DesktopWindow(title: "Browser")
        windows.append(window)
        activeWindowID = window.id
    }

    func activate(_ id: UUID) {
        let switchingWindows = activeWindowID != id
        activeWindowID = id
        if switchingWindows { wantsPhoneKeyboard = false }
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: index)
        windows.append(window)
        updateCursorAffordance()
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
        restoreFrames[id] = nil
        snapTargets[id] = nil
        if activeWindowID == id {
            activeWindowID = windows.last?.id
            wantsPhoneKeyboard = false
        }
        if dragWindowID == id || resizeWindowID == id {
            cancelWindowManipulation()
        }
        updateCursorAffordance()
    }

    func minimize(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = true }
        if activeWindowID == id { wantsPhoneKeyboard = false }
        activeWindowID = windows.last(where: { !$0.isMinimized && $0.id != id })?.id
        updateCursorAffordance()
    }

    func toggleMaximize(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        if windows[index].isMaximized {
            windows[index].isMaximized = false
            if let restore = restoreFrames[id] {
                windows[index].normalizedFrame = restore
            }
            restoreFrames[id] = nil
            snapTargets[id] = nil
        } else {
            // If this window was already snapped, keep the original floating
            // geometry instead of replacing it with the snap rectangle.
            if restoreFrames[id] == nil {
                restoreFrames[id] = windows[index].normalizedFrame
            }
            windows[index].isMaximized = true
            snapTargets[id] = nil
        }
        activate(id)
    }

    func restoreAndActivate(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = false }
        activate(id)
    }

    /// Explicit placement path used by window-management commands. Pointer drag
    /// no longer invokes snapping just because it reaches a display edge.
    func snapWindow(_ id: UUID, to target: WindowSnapEngine.SnapTarget) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }

        if restoreFrames[id] == nil && !windows[index].isMaximized {
            restoreFrames[id] = windows[index].normalizedFrame
        }

        if target == .maximize {
            windows[index].isMaximized = true
            snapTargets[id] = nil
        } else {
            windows[index].isMaximized = false
            windows[index].normalizedFrame = WindowSnapEngine.frame(for: target)
            snapTargets[id] = target
        }
        activate(id)
    }

    func movePointer(delta: CGSize, sensitivity: CGFloat = 1.0) {
        let dx = delta.width / 430 * sensitivity
        let dy = delta.height / 800 * sensitivity
        cursor.x = min(max(cursor.x + dx, 0.006), 0.994)
        cursor.y = min(max(cursor.y + dy, 0.006), 0.994)
        updateCursorAffordance()
    }

    func primaryClick() {
        pulseCursor(.clicking)
        guard let id = topWindow(at: cursor) else { return }
        activate(id)
    }

    /// Preserved compatibility entry point.
    func beginPrimaryDrag() {
        _ = beginPrimaryDragIfPossible()
    }

    @discardableResult
    func beginPrimaryDragIfPossible() -> Bool {
        guard dragWindowID == nil, resizeWindowID == nil,
              let id = topWindow(at: cursor),
              let index = windows.firstIndex(where: { $0.id == id }) else { return false }

        let visibleFrame = effectiveFrame(for: windows[index])
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: visibleFrame)
        guard cursor.y >= visibleFrame.minY,
              cursor.y <= visibleFrame.minY + titleBarHeight else { return false }

        // Preserve where the pointer grabbed the title bar. When pulling a
        // snapped/maximized window away from an edge, restore its previous
        // floating size under that same pointer instead of dragging a huge
        // half-screen rectangle around the desktop.
        let horizontalAnchor = min(max((cursor.x - visibleFrame.minX) / max(visibleFrame.width, 0.001), 0.08), 0.92)
        let titleAnchor = min(max((cursor.y - visibleFrame.minY) / max(titleBarHeight, 0.001), 0.10), 0.90)
        let wasSpatiallyPlaced = windows[index].isMaximized || snapTargets[id] != nil

        if wasSpatiallyPlaced, let floating = restoreFrames[id] {
            var restored = floating
            let restoredTitleHeight = DesktopWindowChrome.titleBarHeight(for: restored)
            restored.origin.x = cursor.x - restored.width * horizontalAnchor
            restored.origin.y = cursor.y - restoredTitleHeight * titleAnchor
            restored.origin.x = min(max(restored.origin.x, 0.006), 0.994 - restored.width)
            restored.origin.y = min(max(restored.origin.y, 0.045), 0.885 - restored.height)

            windows[index].isMaximized = false
            windows[index].normalizedFrame = restored
            restoreFrames[id] = nil
            snapTargets[id] = nil
        }

        wantsPhoneKeyboard = false
        activate(id)
        guard let active = windows.first(where: { $0.id == id }) else { return false }
        dragWindowID = id
        dragOffset = CGPoint(
            x: cursor.x - active.normalizedFrame.minX,
            y: cursor.y - active.normalizedFrame.minY
        )
        cursorInteractionState = .dragging
        return true
    }

    func updatePrimaryDrag(delta: CGSize) {
        movePointer(delta: delta)
        guard let id = dragWindowID else { return }

        mutateWindow(id) { window in
            let width = window.normalizedFrame.width
            let height = window.normalizedFrame.height
            let newX = min(max(cursor.x - dragOffset.x, 0.006), 0.994 - width)
            let newY = min(max(cursor.y - dragOffset.y, 0.045), 0.885 - height)
            window.normalizedFrame.origin = CGPoint(x: newX, y: newY)
        }

        // Edge contact is no longer an implicit resize/snap command.
        snapPreviewTarget = nil
        cursorInteractionState = .dragging
    }

    func endPrimaryDrag() {
        dragWindowID = nil
        snapPreviewTarget = nil
        updateCursorAffordance()
    }

    @discardableResult
    func beginWindowResizeIfPossible() -> Bool {
        guard dragWindowID == nil, resizeWindowID == nil,
              let hit = resizeHit(at: cursor),
              let index = windows.firstIndex(where: { $0.id == hit.id }),
              !windows[index].isMaximized else { return false }

        // Resizing a snapped window detaches it from the snap layout. Gesture
        // ownership is enforced by TrackpadEngine: resize requires two fingers.
        snapTargets[hit.id] = nil
        restoreFrames[hit.id] = nil
        wantsPhoneKeyboard = false

        activate(hit.id)
        resizeWindowID = hit.id
        resizeEdge = hit.edge
        resizeStartFrame = windows.first(where: { $0.id == hit.id })?.normalizedFrame ?? .zero
        resizeStartCursor = cursor
        cursorInteractionState = .resizing(edge: hit.edge.rawValue)
        return true
    }

    func updateWindowResize(delta: CGSize) {
        movePointer(delta: delta)
        guard let id = resizeWindowID, let edge = resizeEdge else { return }

        let dx = cursor.x - resizeStartCursor.x
        let dy = cursor.y - resizeStartCursor.y
        let minWidth: CGFloat = 0.24
        let minHeight: CGFloat = 0.22
        let leftBound: CGFloat = 0.006
        let rightBound: CGFloat = 0.994
        let topBound: CGFloat = 0.045
        let bottomBound: CGFloat = 0.885

        var frame = resizeStartFrame

        if edge == .left || edge == .topLeft || edge == .bottomLeft {
            let newMinX = min(max(resizeStartFrame.minX + dx, leftBound), resizeStartFrame.maxX - minWidth)
            frame.origin.x = newMinX
            frame.size.width = resizeStartFrame.maxX - newMinX
        }
        if edge == .right || edge == .topRight || edge == .bottomRight {
            frame.size.width = min(max(resizeStartFrame.width + dx, minWidth), rightBound - resizeStartFrame.minX)
        }
        if edge == .top || edge == .topLeft || edge == .topRight {
            let newMinY = min(max(resizeStartFrame.minY + dy, topBound), resizeStartFrame.maxY - minHeight)
            frame.origin.y = newMinY
            frame.size.height = resizeStartFrame.maxY - newMinY
        }
        if edge == .bottom || edge == .bottomLeft || edge == .bottomRight {
            frame.size.height = min(max(resizeStartFrame.height + dy, minHeight), bottomBound - resizeStartFrame.minY)
        }

        mutateWindow(id) { window in
            window.isMaximized = false
            window.normalizedFrame = frame
        }
        cursorInteractionState = .resizing(edge: edge.rawValue)
    }

    func endWindowResize() {
        resizeWindowID = nil
        resizeEdge = nil
        updateCursorAffordance()
    }

    func cancelWindowManipulation() {
        dragWindowID = nil
        resizeWindowID = nil
        resizeEdge = nil
        snapPreviewTarget = nil
        updateCursorAffordance()
    }

    var hasActiveWindowDrag: Bool { dragWindowID != nil }
    var hasActiveWindowResize: Bool { resizeWindowID != nil }

    func resizeEdgeAtCursor() -> ResizeEdge? {
        resizeHit(at: cursor)?.edge
    }

    private func mutateWindow(_ id: UUID, _ update: (inout DesktopWindow) -> Void) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        update(&windows[index])
    }

    func topWindow(at point: CGPoint) -> UUID? {
        windows.reversed().first(where: {
            !$0.isMinimized && effectiveFrame(for: $0).contains(point)
        })?.id
    }

    func effectiveFrame(for window: DesktopWindow) -> CGRect {
        if window.isMaximized {
            return WindowSnapEngine.frame(for: .maximize)
        }
        return window.normalizedFrame
    }

    private func resizeHit(at point: CGPoint) -> (id: UUID, edge: ResizeEdge)? {
        let threshold: CGFloat = 0.012

        for window in windows.reversed() where !window.isMinimized && !window.isMaximized {
            let frame = window.normalizedFrame
            let expanded = frame.insetBy(dx: -threshold, dy: -threshold)
            guard expanded.contains(point) else { continue }

            let nearLeft = abs(point.x - frame.minX) <= threshold
            let nearRight = abs(point.x - frame.maxX) <= threshold
            let nearTop = abs(point.y - frame.minY) <= threshold
            let nearBottom = abs(point.y - frame.maxY) <= threshold

            if nearLeft && nearTop { return (window.id, .topLeft) }
            if nearRight && nearTop { return (window.id, .topRight) }
            if nearLeft && nearBottom { return (window.id, .bottomLeft) }
            if nearRight && nearBottom { return (window.id, .bottomRight) }
            if nearLeft { return (window.id, .left) }
            if nearRight { return (window.id, .right) }
            if nearTop { return (window.id, .top) }
            if nearBottom { return (window.id, .bottom) }
        }
        return nil
    }

    private func updateCursorAffordance() {
        if let edge = resizeEdge {
            cursorInteractionState = .resizing(edge: edge.rawValue)
        } else if dragWindowID != nil {
            cursorInteractionState = .dragging
        } else {
            // Merely hovering an edge never implies that a one-finger move will
            // resize it; resize feedback appears only after the two-finger resize begins.
            cursorInteractionState = .defaultState
        }
    }

    private func pulseCursor(_ state: CursorInteractionState) {
        cursorInteractionState = state
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            self?.updateCursorAffordance()
        }
    }
}
