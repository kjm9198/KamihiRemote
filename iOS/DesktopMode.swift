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
            normalizedFrame: CGRect = CGRect(x: 0.17, y: 0.14, width: 0.66, height: 0.68),
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

    @Published private(set) var isExternalDisplayConnected = false
    @Published var cursor = CGPoint(x: 0.5, y: 0.45)
    @Published var windows: [DesktopWindow] = []
    @Published var activeWindowID: UUID?

    private var dragWindowID: UUID?
    private var dragOffset = CGPoint.zero

    private init() {}

    func externalDisplayDidConnect() {
        isExternalDisplayConnected = true
        if windows.isEmpty {
            openBrowser()
        }
    }

    func externalDisplayDidDisconnect() {
        isExternalDisplayConnected = false
        dragWindowID = nil
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
        activeWindowID = id
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: index)
        windows.append(window)
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
        if activeWindowID == id {
            activeWindowID = windows.last?.id
        }
    }

    func minimize(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = true }
        activeWindowID = windows.last(where: { !$0.isMinimized && $0.id != id })?.id
    }

    func toggleMaximize(_ id: UUID) {
        mutateWindow(id) { window in
            window.isMaximized.toggle()
        }
        activate(id)
    }

    func restoreAndActivate(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = false }
        activate(id)
    }

    func movePointer(delta: CGSize, sensitivity: CGFloat = 1.35) {
        let dx = delta.width / 430 * sensitivity
        let dy = delta.height / 800 * sensitivity
        cursor.x = min(max(cursor.x + dx, 0.006), 0.994)
        cursor.y = min(max(cursor.y + dy, 0.006), 0.994)
    }

    func primaryClick() {
        if cursor.y > 0.91 {
            openBrowser()
            return
        }

        guard let id = topWindow(at: cursor) else { return }
        activate(id)
    }

    func beginPrimaryDrag() {
        guard let id = topWindow(at: cursor),
              let window = windows.first(where: { $0.id == id }),
              !window.isMaximized else { return }

        let titleBarHeight: CGFloat = 0.07
        guard cursor.y >= window.normalizedFrame.minY,
              cursor.y <= window.normalizedFrame.minY + titleBarHeight else { return }

        activate(id)
        dragWindowID = id
        dragOffset = CGPoint(
            x: cursor.x - window.normalizedFrame.minX,
            y: cursor.y - window.normalizedFrame.minY
        )
    }

    func updatePrimaryDrag(delta: CGSize) {
        movePointer(delta: delta)
        guard let id = dragWindowID else { return }

        mutateWindow(id) { window in
            let width = window.normalizedFrame.width
            let height = window.normalizedFrame.height
            let newX = min(max(cursor.x - dragOffset.x, 0), 1 - width)
            let newY = min(max(cursor.y - dragOffset.y, 0.035), 0.90 - height)
            window.normalizedFrame.origin = CGPoint(x: newX, y: newY)
        }
    }

    func endPrimaryDrag() {
        dragWindowID = nil
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
            return CGRect(x: 0.015, y: 0.055, width: 0.97, height: 0.84)
        }
        return window.normalizedFrame
    }
}
