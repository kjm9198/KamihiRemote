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
        if let target = DesktopDockHitRegistry.shared.hitTest(at: cursor) {
            wantsPhoneKeyboard = false
            primaryClick()
            switch target {
            case .menuBarButton(let menu):
                if activeMenuBarMenu == menu {
                    activeMenuBarMenu = nil
                } else {
                    activeMenuBarMenu = menu
                    showControlCenter = false
                    showNotifications = false
                }
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return

            case .menuBarDropdownItem(let actionId):
                executeMenuBarAction(actionId)
                activeMenuBarMenu = nil
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return

            case .menuBarDropdownContainer:
                return

            case .menuBarDismiss:
                activeMenuBarMenu = nil
                return

            case .launcherToggle:
                activeMenuBarMenu = nil
                DesktopDockHitRegistry.shared.onToggleLauncher?()
                return

            case .wallpaperToggle:
                activeMenuBarMenu = nil
                DesktopDockHitRegistry.shared.onToggleWallpaper?()
                return

            case .wallpaperOption(let id):
                DesktopWallpaperManager.shared.selectWallpaper(id: id)
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return

            case .wallpaperDismiss:
                showWallpaperPicker = false
                return

            case .launcherApp(let title, let url):
                DesktopDockHitRegistry.shared.lastLauncherClickSample = nil
                DesktopDockHitRegistry.shared.selectedLauncherTitle = title
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
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
                return

            case .launcherContainer:
                return

            case .launcherDismiss:
                DesktopDockHitRegistry.shared.isLauncherOpen = false
                DesktopDockHitRegistry.shared.onDismissLauncher?()
                return

            case .app(let title):
                activeMenuBarMenu = nil
                if let window = windows.first(where: { $0.title == title }) {
                    restoreAndActivate(window.id)
                } else {
                    openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
                }
                return
            }
        }

        if activeMenuBarMenu != nil {
            activeMenuBarMenu = nil
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
            } else if cursor.x <= 0.05 {
                activeMenuBarMenu = (activeMenuBarMenu == .apple ? nil : .apple)
                return
            } else if cursor.x > 0.05 && cursor.x <= 0.12 {
                activeMenuBarMenu = (activeMenuBarMenu == .file ? nil : .file)
                return
            } else if cursor.x > 0.12 && cursor.x <= 0.16 {
                activeMenuBarMenu = (activeMenuBarMenu == .edit ? nil : .edit)
                return
            } else if cursor.x > 0.16 && cursor.x <= 0.20 {
                activeMenuBarMenu = (activeMenuBarMenu == .view ? nil : .view)
                return
            } else if cursor.x > 0.20 && cursor.x <= 0.26 {
                activeMenuBarMenu = (activeMenuBarMenu == .window ? nil : .window)
                return
            } else if cursor.x > 0.26 && cursor.x <= 0.34 {
                activeMenuBarMenu = (activeMenuBarMenu == .help ? nil : .help)
                return
            }
        }

        if showNotifications || showControlCenter {
            if cursor.y > 0.035 && cursor.x < 0.68 {
                showNotifications = false
                showControlCenter = false
            }
        }

        if let assist = splitAssistState {
            let assistFrame = WindowSnapEngine.frame(for: assist.target)
            if assistFrame.contains(cursor) {
                primaryClick()
                let clickPtX = (cursor.x - assistFrame.minX) / assistFrame.width
                let clickPtY = (cursor.y - assistFrame.minY) / assistFrame.height

                // Top right "✕" close button
                if clickPtX > 0.88 && clickPtY < 0.14 {
                    dismissSplitAssist()
                    return
                }

                // Eligible candidate cards
                let eligible = windows.filter { assist.eligibleWindowIDs.contains($0.id) }
                if !eligible.isEmpty {
                    let relativeY = clickPtY - 0.18
                    if relativeY >= 0 {
                        let row = Int(relativeY / 0.28)
                        let col = clickPtX < 0.5 ? 0 : 1
                        let index = row * 2 + col
                        if index >= 0 && index < eligible.count {
                            let chosenID = eligible[index].id
                            snapWindow(chosenID, to: assist.target)
                            dismissSplitAssist()
                            return
                        }
                    }
                }
                return
            } else {
                dismissSplitAssist()
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

        if window.title == "Photos" {
            handlePhotosClick(at: cursor, in: frame)
            return
        }

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

    public func executeMenuBarAction(_ actionId: String) {
        switch actionId {
        case "apple.about", "apple.settings":
            openProductivityApp("Settings", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
        case "apple.tutorial", "help.tutorial":
            UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
        case "apple.wallpaper", "view.wallpaper":
            showWallpaperPicker.toggle()
        case "apple.widgets", "view.widgets":
            let current = UserDefaults.standard.object(forKey: "kamihi.desktop.showWidgets") as? Bool ?? true
            UserDefaults.standard.set(!current, forKey: "kamihi.desktop.showWidgets")
        case "apple.closeAll":
            closeAllDesktopWindows()
        case "file.newWindow":
            openProductivityApp("Documents", frame: CGRect(x: 0.22, y: 0.18, width: 0.58, height: 0.62))
        case "file.newTab":
            openProductivityApp("Browser", frame: CGRect(x: 0.18, y: 0.15, width: 0.64, height: 0.68))
            DesktopBrowserState.shared.newTab()
        case "file.closeWindow":
            if let active = activeWindowID { close(active) }
        case "edit.cut":
            if let _ = UIPasteboard.general.string { deleteBackwardInActiveDesktopField() }
        case "edit.copy":
            break
        case "edit.paste":
            if let str = UIPasteboard.general.string { typeIntoActiveDesktopField(str) }
        case "edit.selectAll":
            if let title = activeWindow?.title {
                DesktopWebInputRegistry.shared.click(key: title, x: 0.5, y: 0.5) { _ in }
            }
        case "view.resetLayout":
            openVibeWorkspace()
        case "window.minimize":
            if let active = activeWindowID { minimize(active) }
        case "window.zoom":
            if let active = activeWindowID { toggleMaximize(active) }
        case "window.tileLeft":
            snapActiveLeft()
        case "window.tileRight":
            snapActiveRight()
        case "window.bringFront":
            for window in windows { restoreAndActivate(window.id) }
        case "help.diagnostics":
            openProductivityApp("Display Diagnostics", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
        default:
            break
        }
    }

    private func handleDocumentsClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        guard point.y > contentTop, frame.width > 0, frame.height > 0 else { return }

        let windowPtWidth = frame.width * 1920
        let clickPtX = (point.x - frame.minX) * 1920
        let clickPtY = (point.y - contentTop) * 1080

        let sidebarWidth: CGFloat = 220
        let toolbarHeight: CGFloat = 44

        if clickPtX <= sidebarWidth {
            // Sidebar region
            if clickPtY <= toolbarHeight && clickPtX >= (sidebarWidth - 44) {
                // "New document" button on top right of sidebar toolbar
                DesktopDocumentsStore.shared.createDocument()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if clickPtY > toolbarHeight {
                // Document list selection (46 pt row + 4 pt spacing, starting at 7 pt padding)
                let store = DesktopDocumentsStore.shared
                let count = store.documents.count
                if count > 0 {
                    let rowOffset = clickPtY - toolbarHeight - 7
                    if rowOffset >= 0 {
                        let clickedIndex = min(max(Int(rowOffset / 50), 0), count - 1)
                        store.select(store.documents[clickedIndex].id)
                        wantsPhoneKeyboard = true
                        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                        return
                    }
                }
            }
        } else {
            // Canvas region: top right "+" button
            if clickPtY <= toolbarHeight && clickPtX >= (windowPtWidth - 48) {
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

        let windowPtWidth = frame.width * 1920
        let clickPtX = (point.x - frame.minX) * 1920
        let clickPtY = (point.y - contentTop) * 1080

        let sidebarWidth: CGFloat = 220
        let toolbarHeight: CGFloat = 44

        if clickPtX <= sidebarWidth {
            if clickPtY <= toolbarHeight && clickPtX >= (sidebarWidth - 44) {
                DesktopNotesStore.shared.createNewNote()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            } else if clickPtY > (toolbarHeight + 34) {
                let store = DesktopNotesStore.shared
                let sorted = store.notes.sorted { $0.updatedAt > $1.updatedAt }
                if !sorted.isEmpty {
                    let rowOffset = clickPtY - toolbarHeight - 34 - 7
                    if rowOffset >= 0 {
                        let clickedIndex = min(max(Int(rowOffset / 54), 0), sorted.count - 1)
                        store.select(sorted[clickedIndex].id)
                        wantsPhoneKeyboard = true
                        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                        return
                    }
                }
            }
        } else {
            if clickPtY <= toolbarHeight && clickPtX >= (windowPtWidth - 48) {
                DesktopNotesStore.shared.createNewNote()
                wantsPhoneKeyboard = true
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                return
            }
        }

        wantsPhoneKeyboard = true
    }

    private func handlePhotosClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        guard point.y > contentTop, frame.width > 0, frame.height > 0 else { return }

        let windowPtWidth = frame.width * 1920
        let clickPtX = (point.x - frame.minX) * 1920
        let clickPtY = (point.y - contentTop) * 1080

        let store = DesktopPhotosStore.shared
        let sidebarWidth: CGFloat = 174
        let toolbarHeight: CGFloat = DesktopShellMetrics.toolbarHeight

        // Check sidebar click
        if clickPtX <= sidebarWidth {
            let rowY = clickPtY - toolbarHeight - 7
            if rowY >= 0 {
                let rowIndex = Int(rowY / 34)
                if rowIndex == 0 {
                    store.selectedFilter = .library
                    store.select(assetID: nil)
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                } else if rowIndex == 1 {
                    store.selectedFilter = .favorites
                    store.select(assetID: nil)
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                } else if rowIndex == 2 {
                    store.selectedFilter = .recent
                    store.select(assetID: nil)
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
            }
            return
        }

        // Inside content area
        let contentX = clickPtX - sidebarWidth
        let contentY = clickPtY
        let contentWidth = windowPtWidth - sidebarWidth

        // If a photo is currently selected (Detail View)
        if store.selectedAsset != nil {
            if contentY <= toolbarHeight {
                // Left: "Back to Photos" button [0...100]
                if contentX <= 100 {
                    store.select(assetID: nil)
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
                // Rightmost: "Delete" button [contentWidth - 85 ... contentWidth]
                if contentX >= contentWidth - 85 {
                    store.deleteSelectedAsset()
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
                // Middle right: "Favorite" button [contentWidth - 135 ... contentWidth - 85]
                if contentX >= contentWidth - 135 && contentX < contentWidth - 85 {
                    store.toggleFavoriteSelectedAsset()
                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    return
                }
            }
            return
        }

        // Grid View
        if contentY <= toolbarHeight {
            return
        }

        // Grid items
        let gridX = contentX - 10
        let gridY = contentY - toolbarHeight - 10
        let availableWidth = contentWidth - 20
        guard gridX >= 0, gridY >= 0, availableWidth > 80 else { return }

        let approxItemWidth: CGFloat = 120
        let numCols = max(1, Int((availableWidth + 8) / (approxItemWidth + 8)))
        let actualItemWidth = (availableWidth - CGFloat(numCols - 1) * 8) / CGFloat(numCols)
        let itemHeight = actualItemWidth

        let col = Int(gridX / (actualItemWidth + 8))
        let row = Int(gridY / (itemHeight + 8))

        if col >= 0 && col < numCols && row >= 0 {
            let index = row * numCols + col
            if index < store.assets.count {
                store.selectIndex(index)
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
            }
        }
    }
}
