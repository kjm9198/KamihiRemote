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
        if DesktopDockHitRegistry.shared.isLauncherOpen {
            wantsPhoneKeyboard = false
            primaryClick()
            if let hit = DesktopDockHitRegistry.shared.hitTest(at: cursor) {
                switch hit {
                case .launcherApp(let title, let url):
                    let now = CACurrentMediaTime()
                    if let last = DesktopDockHitRegistry.shared.lastLauncherClickSample,
                       last.title == title,
                       (now - last.time) <= 0.60 {
                        DesktopDockHitRegistry.shared.lastLauncherClickSample = nil
                        if let url {
                            DesktopBrowserState.shared.newTab(url: url)
                            if let existing = windows.first(where: { $0.title == "Browser" }) {
                                restoreAndActivate(existing.id)
                            } else {
                                openProductivityApp("Browser", frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
                            }
                        } else if let existing = windows.first(where: { $0.title == title }) {
                            restoreAndActivate(existing.id)
                        } else {
                            openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
                        }
                        DesktopDockHitRegistry.shared.isLauncherOpen = false
                        DesktopDockHitRegistry.shared.onDismissLauncher?()
                    } else {
                        DesktopDockHitRegistry.shared.lastLauncherClickSample = (title: title, time: now)
                        DesktopDockHitRegistry.shared.selectedLauncherTitle = title
                        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    }
                    return
                case .launcherContainer:
                    // Swallowing click inside launcher background/search
                    return
                case .launcherDismiss:
                    DesktopDockHitRegistry.shared.isLauncherOpen = false
                    DesktopDockHitRegistry.shared.onDismissLauncher?()
                    return
                default:
                    break
                }
            } else {
                DesktopDockHitRegistry.shared.isLauncherOpen = false
                DesktopDockHitRegistry.shared.onDismissLauncher?()
                return
            }
        }

        if let dockTarget = DesktopDockHitRegistry.shared.hitTest(at: cursor) {
            wantsPhoneKeyboard = false
            primaryClick()
            switch dockTarget {
            case .launcherToggle:
                DesktopDockHitRegistry.shared.onToggleLauncher?()
            case .app(let title):
                if let window = windows.first(where: { $0.title == title }) {
                    restoreAndActivate(window.id)
                } else {
                    openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
                }
            default:
                break
            }
            return
        }

        if cursor.y <= 0.035 {
            primaryClick()
            if cursor.x >= 0.85 {
                showNotifications.toggle()
                showControlCenter = false
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if cursor.x >= 0.76 && cursor.x < 0.85 {
                showControlCenter.toggle()
                showNotifications = false
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if cursor.x >= 0.70 && cursor.x < 0.76 {
                openProductivityApp("Display Diagnostics", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                return
            }
        }

        if showNotifications || showControlCenter {
            if cursor.y > 0.035 && cursor.x < 0.68 {
                showNotifications = false
                showControlCenter = false
            }
        }

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
        if window.title == "Documents" {
            handleDocumentsClick(at: cursor, in: frame)
            return
        }

        if window.title == "Notes" {
            handleNotesClick(at: cursor, in: frame)
            return
        }

        if window.title == "Sheets" {
            guard let cell = sheetsCell(at: cursor, in: frame) else {
                wantsPhoneKeyboard = false
                return
            }
            DesktopSheetsStore.shared.select(row: cell.row, column: cell.column)
            wantsPhoneKeyboard = true
            return
        }

        if window.title == "Browser" {
            let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
            let chromeTop = frame.minY + titleBarHeight
            let chromeBottom = chromeTop + 0.078
            if cursor.y >= chromeTop && cursor.y < chromeBottom {
                // Clicking in the lower portion of browser chrome activates the URL address bar
                if cursor.y >= chromeBottom - 0.044 {
                    wantsPhoneKeyboard = true
                }
                return
            }
        }

        guard let point = webContentPoint(at: cursor, in: frame, for: window.title) else {
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
              window.title != "Sheets",
              let point = webContentPoint(at: cursor, in: effectiveFrame(for: window), for: window.title) else { return }

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
        if resizeEdgeAtCursor() != nil {
            return beginPointerResize()
        }
        return beginPrimaryDragIfPossible()
    }

    public func updateWindowDrag(delta: CGSize) {
        if isResizingWindow {
            updatePointerResize(delta: delta)
        } else {
            updatePrimaryDrag(delta: delta)
        }
    }

    public func endWindowDrag() {
        if isResizingWindow {
            endPointerResize()
        } else {
            endPrimaryDrag()
        }
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
        guard let key = activeWindow?.title else { return }
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
        case "Sheets":
            DesktopSheetsStore.shared.appendToActiveCell(text)
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
        case "Sheets":
            DesktopSheetsStore.shared.deleteBackwardFromActiveCell()
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
        case "Sheets":
            DesktopSheetsStore.shared.commitAndMoveDown()
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

    /// Resolve the software pointer against the exact geometry used by
    /// `DesktopSheetsView`. The previous percentage-based hit test ignored the
    /// 42pt Sheets toolbar and used approximate header fractions, so cells near
    /// the top/left (and resized windows) could select the wrong row or column.
    private func sheetsCell(at point: CGPoint, in frame: CGRect) -> (row: Int, column: Int)? {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        let contentHeight = frame.maxY - contentTop
        guard frame.width > 0, contentHeight > 0 else { return nil }

        let localX = point.x - frame.minX
        let localY = point.y - contentTop

        let appToolbarHeight: CGFloat = 42
        let rowHeaderWidth: CGFloat = 44
        let columnHeaderHeight: CGFloat = 32
        let gridViewportHeight = contentHeight - appToolbarHeight
        guard gridViewportHeight > columnHeaderHeight else { return nil }

        let cellWidth = max(
            54,
            (frame.width - rowHeaderWidth) / CGFloat(DesktopSheetsStore.columnCount)
        )
        let cellHeight = max(
            22,
            (gridViewportHeight - columnHeaderHeight) / CGFloat(DesktopSheetsStore.rowCount)
        )

        let gridX = localX - rowHeaderWidth
        let gridY = localY - appToolbarHeight - columnHeaderHeight
        guard gridX >= 0,
              gridY >= 0,
              gridX < cellWidth * CGFloat(DesktopSheetsStore.columnCount),
              gridY < cellHeight * CGFloat(DesktopSheetsStore.rowCount) else { return nil }

        return (
            row: min(Int(gridY / cellHeight), DesktopSheetsStore.rowCount - 1),
            column: min(Int(gridX / cellWidth), DesktopSheetsStore.columnCount - 1)
        )
    }

    private func webContentPoint(at point: CGPoint, in frame: CGRect, for appTitle: String = "Browser") -> CGPoint? {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let appChromeHeight: CGFloat
        switch appTitle {
        case "Browser":
            appChromeHeight = 0.078 // 84pt / 1080p canvas
        case "YouTube", "ChatGPT":
            appChromeHeight = 0.030 // ~32pt / 1080p canvas
        default:
            appChromeHeight = 0.0
        }
        let contentTop = frame.minY + titleBarHeight + appChromeHeight
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

    private func handleDocumentsClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        guard point.y > contentTop, frame.width > 0, frame.height > 0 else { return }

        let localX = (point.x - frame.minX) / frame.width
        let localY = (point.y - contentTop) / (frame.maxY - contentTop)
        let sidebarFraction: CGFloat = 0.28

        if localX <= sidebarFraction {
            // Sidebar region
            if localY <= 0.12 && localX >= (sidebarFraction - 0.08) {
                // "New document" button on top of sidebar
                DesktopDocumentsStore.shared.createDocument()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if localY > 0.12 {
                // Document row selection
                let store = DesktopDocumentsStore.shared
                let count = store.documents.count
                if count > 0 {
                    let clickedIndex = min(max(Int((localY - 0.12) / 0.11), 0), count - 1)
                    store.select(store.documents[clickedIndex].id)
                    wantsPhoneKeyboard = true
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
            }
        } else {
            // Canvas region: top right "+" button
            if localY <= 0.12 && localX >= 0.88 {
                DesktopDocumentsStore.shared.createDocument()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            }
        }

        wantsPhoneKeyboard = true
    }

    private func handleNotesClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        guard point.y > contentTop, frame.width > 0, frame.height > 0 else { return }

        let localX = (point.x - frame.minX) / frame.width
        let localY = (point.y - contentTop) / (frame.maxY - contentTop)
        let sidebarFraction: CGFloat = 0.28

        if localX <= sidebarFraction {
            if localY <= 0.12 && localX >= (sidebarFraction - 0.08) {
                DesktopNotesStore.shared.createNewNote()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if localY > 0.18 {
                let store = DesktopNotesStore.shared
                let sorted = store.notes.sorted { $0.updatedAt > $1.updatedAt }
                if !sorted.isEmpty {
                    let clickedIndex = min(max(Int((localY - 0.18) / 0.12), 0), sorted.count - 1)
                    store.select(sorted[clickedIndex].id)
                    wantsPhoneKeyboard = true
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
            }
        } else {
            if localY <= 0.12 && localX >= 0.88 {
                DesktopNotesStore.shared.deleteActiveNote()
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            }
        }

        wantsPhoneKeyboard = true
    }
}
