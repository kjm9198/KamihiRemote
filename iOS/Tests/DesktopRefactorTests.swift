import Foundation
import CoreGraphics

/// Automated runtime self-checks for the Kamihi Desktop architecture.
public enum DesktopRefactorTests {
    public struct TestResult {
        public let name: String
        public let passed: Bool
        public let message: String
    }

    @MainActor
    public static func runSelfChecks() -> [TestResult] {
        var results: [TestResult] = []

        // Test 1: Kamihi Desktop is the only product mode.
        do {
            let router = AppModeRouter()
            router.selectMode(.externalDesktop)
            guard router.currentMode == .externalDesktop else {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to switch to Kamihi Desktop"])
            }
            router.returnToChooser()
            guard router.currentMode == .none else {
                throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to leave Kamihi Desktop"])
            }
            router.startDesktopLab()
            guard router.currentMode == .externalDesktop, router.isDesktopLabActive else {
                throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Desktop Lab did not enter Kamihi Desktop"])
            }
            results.append(TestResult(name: "Kamihi Desktop Router State Transitions", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Kamihi Desktop Router State Transitions", passed: false, message: error.localizedDescription))
        }

        // Test 2: Window Snap Geometry Invariants
        do {
            for target in WindowSnapEngine.SnapTarget.allCases {
                let frame = WindowSnapEngine.frame(for: target)
                guard frame.origin.x >= 0, frame.origin.y >= 0,
                      frame.maxX <= 1.0, frame.maxY <= 1.0,
                      frame.width > 0, frame.height > 0 else {
                    throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Snap target \(target.rawValue) produced out-of-bounds frame \(frame)"])
                }
            }
            results.append(TestResult(name: "WindowSnapEngine Geometry Bounds", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "WindowSnapEngine Geometry Bounds", passed: false, message: error.localizedDescription))
        }

        // Test 3: Browser URL Normalization
        do {
            let queryURL = DesktopBrowserState.normalizeURL("swift programming")
            guard queryURL?.host == "www.google.com" else {
                throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Search query normalization failed"])
            }

            let directURL = DesktopBrowserState.normalizeURL("https://apple.com")
            guard directURL?.host == "apple.com" else {
                throw NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Direct URL normalization failed"])
            }

            let schemaURL = DesktopBrowserState.normalizeURL("github.com")
            guard schemaURL?.host == "github.com" else {
                throw NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Implicit https URL normalization failed"])
            }
            results.append(TestResult(name: "DesktopBrowserState URL Normalization", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "DesktopBrowserState URL Normalization", passed: false, message: error.localizedDescription))
        }

        // Test 4: Notes Store Persistence
        do {
            let store = DesktopNotesStore.shared
            let countBefore = store.notes.count
            store.createNewNote()
            guard store.notes.count == countBefore + 1 else {
                throw NSError(domain: "Test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to insert new note"])
            }
            if let active = store.activeNoteID {
                store.deleteNote(id: active)
            }
            results.append(TestResult(name: "DesktopNotesStore Persistence", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "DesktopNotesStore Persistence", passed: false, message: error.localizedDescription))
        }

        // Test 5: Pointer physics must preserve precision while accelerating fast sweeps.
        do {
            let slow = TrackpadEngine.physicsDelta(
                dx: 1,
                dy: 0,
                dt: 1.0 / 60.0,
                sensitivity: 1.0,
                acceleration: 1.0,
                precisionMode: false
            )
            let fast = TrackpadEngine.physicsDelta(
                dx: 12,
                dy: 0,
                dt: 1.0 / 120.0,
                sensitivity: 1.0,
                acceleration: 1.0,
                precisionMode: false
            )
            let precise = TrackpadEngine.physicsDelta(
                dx: 12,
                dy: 0,
                dt: 1.0 / 120.0,
                sensitivity: 1.0,
                acceleration: 1.0,
                precisionMode: true
            )
            let zero = TrackpadEngine.physicsDelta(
                dx: 0,
                dy: 0,
                dt: 1.0 / 60.0,
                sensitivity: 1.0,
                acceleration: 1.0,
                precisionMode: false
            )

            guard slow.width > 0,
                  fast.width > 12,
                  precise.width > 0,
                  precise.width < fast.width,
                  zero == .zero else {
                throw NSError(domain: "Test", code: 9, userInfo: [NSLocalizedDescriptionKey: "Pointer acceleration/precision invariants failed"])
            }
            results.append(TestResult(name: "Trackpad Pointer Physics", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Trackpad Pointer Physics", passed: false, message: error.localizedDescription))
        }

        // Test 6: Software pointer must be able to operate external-display window chrome.
        do {
            let frame = CGRect(x: 0.12, y: 0.10, width: 0.66, height: 0.68)
            let titleHeight = DesktopWindowChrome.titleBarHeight(for: frame)
            let y = frame.minY + titleHeight / 2

            let closeX = frame.minX + 0.009
            let minimizeX = frame.minX + 0.026
            let maximizeX = frame.minX + 0.043

            guard DesktopWindowChrome.action(at: CGPoint(x: closeX, y: y), in: frame) == .close,
                  DesktopWindowChrome.action(at: CGPoint(x: minimizeX, y: y), in: frame) == .minimize,
                  DesktopWindowChrome.action(at: CGPoint(x: maximizeX, y: y), in: frame) == .maximizeRestore,
                  DesktopWindowChrome.action(at: CGPoint(x: frame.midX, y: frame.midY), in: frame) == nil else {
                throw NSError(domain: "Test", code: 10, userInfo: [NSLocalizedDescriptionKey: "Window chrome pointer hit testing failed"])
            }
            results.append(TestResult(name: "Desktop Window Chrome Hit Testing", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Desktop Window Chrome Hit Testing", passed: false, message: error.localizedDescription))
        }

        // Test 7: default app placement is a centered 60% window.
        do {
            let frame = DesktopSession.DesktopWindow(title: "Test").normalizedFrame
            let tolerance: CGFloat = 0.0001
            guard abs(frame.width - 0.60) < tolerance,
                  abs(frame.height - 0.60) < tolerance,
                  abs(frame.midX - 0.50) < tolerance,
                  abs(frame.midY - 0.465) < tolerance else {
                throw NSError(domain: "Test", code: 11, userInfo: [NSLocalizedDescriptionKey: "Default desktop window is not centered at 60%: \(frame)"])
            }
            results.append(TestResult(name: "Centered 60 Percent Window Default", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Centered 60 Percent Window Default", passed: false, message: error.localizedDescription))
        }

        // Test 8: two-finger scrolling has symmetric X/Y gain and direction.
        do {
            let natural = TrackpadEngine.scrollDelta(dx: 8, dy: -8, speed: 1.0, naturalScrolling: true)
            let reversed = TrackpadEngine.scrollDelta(dx: 8, dy: -8, speed: 1.0, naturalScrolling: false)
            let tolerance: CGFloat = 0.0001

            guard abs(abs(natural.width) - abs(natural.height)) < tolerance,
                  abs(reversed.width + natural.width) < tolerance,
                  abs(reversed.height + natural.height) < tolerance,
                  natural.height > 0 else {
                throw NSError(domain: "Test", code: 12, userInfo: [NSLocalizedDescriptionKey: "Horizontal/vertical scroll gains diverged or natural scroll polarity incorrect"])
            }
            results.append(TestResult(name: "Two Axis Scroll Symmetry", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Two Axis Scroll Symmetry", passed: false, message: error.localizedDescription))
        }

        // Test 9: closing an app is a true lifecycle transition. It must disappear
        // from the running window list, clear stale keyboard ownership, and a later
        // explicit launch must create and reveal a new active window.
        do {
            let desktop = DesktopSession.shared
            let title = "Lifecycle Self Check"

            // Keep this check isolated if a previous interrupted run left its
            // synthetic window behind.
            for window in desktop.windows.filter({ $0.title == title }) {
                desktop.close(window.id)
            }

            let firstID = desktop.openProductivityApp(
                title,
                frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)
            )
            desktop.wantsPhoneKeyboard = true
            desktop.close(firstID)

            guard !desktop.windows.contains(where: { $0.id == firstID }),
                  !desktop.windows.contains(where: { $0.title == title }),
                  desktop.wantsPhoneKeyboard == false else {
                throw NSError(domain: "Test", code: 13, userInfo: [NSLocalizedDescriptionKey: "Close did not fully remove the active app or clear keyboard ownership"])
            }

            let reopenedID = desktop.openProductivityApp(title)
            guard reopenedID != firstID,
                  let reopened = desktop.windows.first(where: { $0.id == reopenedID }),
                  reopened.isMinimized == false,
                  desktop.activeWindowID == reopenedID else {
                throw NSError(domain: "Test", code: 14, userInfo: [NSLocalizedDescriptionKey: "Reopening a closed app did not create and reveal a new active window"])
            }

            desktop.close(reopenedID)
            results.append(TestResult(name: "Close And Reopen App Lifecycle", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Close And Reopen App Lifecycle", passed: false, message: error.localizedDescription))
        }

        // Test 10: Dock Hit Testing & Edge Resize Detection
        do {
            let registry = DesktopDockHitRegistry.shared
            registry.update(entries: [
                DesktopDockHitRegistry.Entry(
                    target: .app(title: "Browser"),
                    normalizedFrame: CGRect(x: 0.40, y: 0.90, width: 0.05, height: 0.05)
                )
            ])

            guard registry.hitTest(at: CGPoint(x: 0.42, y: 0.92)) == .app(title: "Browser") else {
                throw NSError(domain: "Test", code: 15, userInfo: [NSLocalizedDescriptionKey: "Dock hit test failed to match registered app tile"])
            }
            guard registry.hitTest(at: CGPoint(x: 0.10, y: 0.10)) == nil else {
                throw NSError(domain: "Test", code: 16, userInfo: [NSLocalizedDescriptionKey: "Dock hit test falsely matched point outside dock"])
            }

            let desktop = DesktopSession.shared
            let testWindowID = desktop.openProductivityApp(
                "Resize Test Window",
                frame: CGRect(x: 0.20, y: 0.20, width: 0.50, height: 0.50)
            )
            desktop.cursor = CGPoint(x: 0.705, y: 0.40)
            guard let edge = desktop.resizeEdgeAtCursor(), edge == .right else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 17, userInfo: [NSLocalizedDescriptionKey: "Failed to detect .right resize edge near window border"])
            }
            desktop.close(testWindowID)
            results.append(TestResult(name: "Dock Hit Testing & Edge Resize Detection", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Dock Hit Testing & Edge Resize Detection", passed: false, message: error.localizedDescription))
        }

        // Test 11: Isometric Cursor Velocity and Maximize Window Integrity
        do {
            let desktop = DesktopSession.shared
            desktop.cursor = CGPoint(x: 0.5, y: 0.5)

            let startCursor = desktop.cursor
            desktop.movePointer(delta: CGSize(width: 10, height: 0), sensitivity: 1.0)
            let deltaDisplayX = (desktop.cursor.x - startCursor.x) * 1920

            desktop.cursor = CGPoint(x: 0.5, y: 0.5)
            desktop.movePointer(delta: CGSize(width: 0, height: 10), sensitivity: 1.0)
            let deltaDisplayY = (desktop.cursor.y - startCursor.y) * 1080

            guard abs(deltaDisplayX - deltaDisplayY) < 0.05 else {
                throw NSError(domain: "Test", code: 18, userInfo: [NSLocalizedDescriptionKey: "Cursor velocity is not isometric: X=\(deltaDisplayX)px, Y=\(deltaDisplayY)px"])
            }

            let testWindowID = desktop.openProductivityApp(
                "Maximize Test Window",
                frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)
            )
            guard let window = desktop.windows.first(where: { $0.id == testWindowID }) else {
                throw NSError(domain: "Test", code: 19, userInfo: [NSLocalizedDescriptionKey: "Window not found"])
            }
            let frame = desktop.effectiveFrame(for: window)
            let titleHeight = DesktopWindowChrome.titleBarHeight(for: frame)
            let maximizeX = frame.minX + 0.043

            desktop.cursor = CGPoint(x: maximizeX, y: frame.minY + titleHeight / 2)
            desktop.clickAtCursor()

            guard let maximizedWindow = desktop.windows.first(where: { $0.id == testWindowID }),
                  maximizedWindow.isMaximized == true else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 20, userInfo: [NSLocalizedDescriptionKey: "Clicking maximize closed or failed to maximize window"])
            }

            desktop.close(testWindowID)
            results.append(TestResult(name: "Isometric Cursor Velocity and Maximize Window Integrity", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Isometric Cursor Velocity and Maximize Window Integrity", passed: false, message: error.localizedDescription))
        }

        // Test 12: Modern Glass Desktop, 120Hz Default, App Library Hit-Testing & Wallpapers
        do {
            // Check 1: 120Hz default preference
            let coordinator = ExternalDisplayCoordinator.shared
            guard coordinator.preferredRefreshRate >= 120 else {
                throw NSError(domain: "Test", code: 21, userInfo: [NSLocalizedDescriptionKey: "preferredRefreshRate does not default to 120Hz: \(coordinator.preferredRefreshRate)"])
            }

            // Check 2: Wallpaper manager presets
            let wpManager = DesktopWallpaperManager.shared
            guard wpManager.wallpapers.count >= 6 else {
                throw NSError(domain: "Test", code: 22, userInfo: [NSLocalizedDescriptionKey: "Wallpaper presets insufficient: \(wpManager.wallpapers.count)"])
            }
            guard !wpManager.currentWallpaper.name.isEmpty else {
                throw NSError(domain: "Test", code: 23, userInfo: [NSLocalizedDescriptionKey: "Current wallpaper name is empty"])
            }

            // Check 3: App Library Hit-Testing when open
            let registry = DesktopDockHitRegistry.shared
            let prevEntries = registry.entries
            let prevOpen = registry.isLauncherOpen

            registry.isLauncherOpen = true
            registry.update(entries: [
                DesktopDockHitRegistry.Entry(
                    target: .launcherApp(title: "YouTube", url: nil),
                    normalizedFrame: CGRect(x: 0.30, y: 0.30, width: 0.10, height: 0.10)
                ),
                DesktopDockHitRegistry.Entry(
                    target: .launcherContainer,
                    normalizedFrame: CGRect(x: 0.20, y: 0.20, width: 0.60, height: 0.60)
                )
            ])

            guard registry.hitTest(at: CGPoint(x: 0.35, y: 0.35)) == .launcherApp(title: "YouTube", url: nil) else {
                throw NSError(domain: "Test", code: 24, userInfo: [NSLocalizedDescriptionKey: "Launcher app tile hit test failed"])
            }
            guard registry.hitTest(at: CGPoint(x: 0.22, y: 0.22)) == .launcherContainer else {
                throw NSError(domain: "Test", code: 25, userInfo: [NSLocalizedDescriptionKey: "Launcher container background hit test failed"])
            }
            guard registry.hitTest(at: CGPoint(x: 0.05, y: 0.05)) == .launcherDismiss else {
                throw NSError(domain: "Test", code: 26, userInfo: [NSLocalizedDescriptionKey: "Launcher click-outside dismiss test failed"])
            }

            // Restore registry state
            registry.update(entries: prevEntries)
            registry.isLauncherOpen = prevOpen

            results.append(TestResult(name: "Modern Glass Desktop, 120Hz Default & App Library Hit-Testing", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Modern Glass Desktop, 120Hz Default & App Library Hit-Testing", passed: false, message: error.localizedDescription))
        }

        // Test 13: Window Chrome Partitioning, Edge Snapping & Title Bar Detection
        do {
            let desktop = DesktopSession.shared
            let testWindowID = desktop.openProductivityApp(
                "Snapping & Title Bar Test",
                frame: CGRect(x: 0.20, y: 0.20, width: 0.60, height: 0.60)
            )
            guard let window = desktop.windows.first(where: { $0.id == testWindowID }) else {
                throw NSError(domain: "Test", code: 27, userInfo: [NSLocalizedDescriptionKey: "Test window missing"])
            }
            let frame = desktop.effectiveFrame(for: window)
            let titleHeight = DesktopWindowChrome.titleBarHeight(for: frame)
            let titleMidY = frame.minY + titleHeight / 2

            // Check 1: Traffic light action partitioning (macOS Left side)
            // Close zone: [frame.minX, frame.minX + 0.018)
            let closeAction = DesktopWindowChrome.action(at: CGPoint(x: frame.minX + 0.009, y: titleMidY), in: frame)
            // Minimize zone: [frame.minX + 0.018, frame.minX + 0.034)
            let minAction = DesktopWindowChrome.action(at: CGPoint(x: frame.minX + 0.026, y: titleMidY), in: frame)
            // Maximize zone: [frame.minX + 0.034, frame.minX + 0.052]
            let maxAction = DesktopWindowChrome.action(at: CGPoint(x: frame.minX + 0.043, y: titleMidY), in: frame)
            // Drag zone (fall-through): > frame.minX + 0.052
            let dragAction = DesktopWindowChrome.action(at: CGPoint(x: frame.minX + 0.080, y: titleMidY), in: frame)

            guard closeAction == .close,
                  minAction == .minimize,
                  maxAction == .maximizeRestore,
                  dragAction == nil else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 28, userInfo: [NSLocalizedDescriptionKey: "Traffic light action partitioning failed: close=\(String(describing: closeAction)), max=\(String(describing: maxAction)), min=\(String(describing: minAction)), drag=\(String(describing: dragAction))"])
            }

            // Check 2: isCursorOverTitleBar detection
            desktop.cursor = CGPoint(x: frame.maxX - 0.05, y: titleMidY)
            guard desktop.isCursorOverTitleBar() == true else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 29, userInfo: [NSLocalizedDescriptionKey: "isCursorOverTitleBar failed to detect cursor over title bar"])
            }

            // In traffic light region (<= frame.minX + 0.105), should NOT trigger title bar drag
            desktop.cursor = CGPoint(x: frame.minX + 0.05, y: titleMidY)
            guard desktop.isCursorOverTitleBar() == false else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 30, userInfo: [NSLocalizedDescriptionKey: "isCursorOverTitleBar falsely matched traffic light button region"])
            }

            // In window body, should NOT trigger title bar drag
            desktop.cursor = CGPoint(x: frame.midX, y: frame.midY)
            guard desktop.isCursorOverTitleBar() == false else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 31, userInfo: [NSLocalizedDescriptionKey: "isCursorOverTitleBar falsely matched window body"])
            }

            // Check 3: Edge snapping intent evaluation
            guard WindowSnapEngine.evaluateSnapIntent(cursor: CGPoint(x: 0.02, y: 0.50)) == .leftHalf,
                  WindowSnapEngine.evaluateSnapIntent(cursor: CGPoint(x: 0.98, y: 0.50)) == .rightHalf,
                  WindowSnapEngine.evaluateSnapIntent(cursor: CGPoint(x: 0.50, y: 0.02)) == .maximize,
                  WindowSnapEngine.evaluateSnapIntent(cursor: CGPoint(x: 0.50, y: 0.50)) == nil else {
                desktop.close(testWindowID)
                throw NSError(domain: "Test", code: 32, userInfo: [NSLocalizedDescriptionKey: "WindowSnapEngine edge snap intent evaluation failed"])
            }

            desktop.close(testWindowID)
            results.append(TestResult(name: "Window Chrome Partitioning, Edge Snapping & Title Bar Detection", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Window Chrome Partitioning, Edge Snapping & Title Bar Detection", passed: false, message: error.localizedDescription))
        }

        // Test 14: Menu Bar Dropdown Activation, Actions & Dismiss
        do {
            let desktop = DesktopSession.shared
            desktop.activeMenuBarMenu = nil

            // 1. Toggle menu bar dropdown
            desktop.activeMenuBarMenu = .file
            guard desktop.activeMenuBarMenu == .file else {
                throw NSError(domain: "Test", code: 33, userInfo: [NSLocalizedDescriptionKey: "Failed to set active menu bar menu"])
            }

            // 2. Execute menu bar action: file.newWindow (opens Documents)
            desktop.executeMenuBarAction("file.newWindow")
            guard desktop.windows.contains(where: { $0.title == "Documents" }) else {
                throw NSError(domain: "Test", code: 34, userInfo: [NSLocalizedDescriptionKey: "file.newWindow did not open Documents"])
            }

            // 3. Close menu bar
            desktop.closeMenuBar()
            guard desktop.activeMenuBarMenu == nil else {
                throw NSError(domain: "Test", code: 35, userInfo: [NSLocalizedDescriptionKey: "closeMenuBar did not reset active menu"])
            }

            // Clean up opened Documents window
            if let docWin = desktop.windows.first(where: { $0.title == "Documents" }) {
                desktop.close(docWin.id)
            }

            results.append(TestResult(name: "Menu Bar Dropdowns & Actions", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Menu Bar Dropdowns & Actions", passed: false, message: error.localizedDescription))
        }

        // Test 15: Dock Auto-Hide, Fullscreen Bounds, and 8-Edge Resize Hit
        do {
            let desktop = DesktopSession.shared

            // 1. Dock Auto-Hide State Machine
            desktop.autohideDock = true
            desktop.cursor = CGPoint(x: 0.50, y: 0.50)
            desktop.movePointer(delta: CGSize(width: 0, height: -10)) // cursor at y < 0.88 -> hidden
            guard desktop.isDockVisible == false else {
                throw NSError(domain: "Test", code: 36, userInfo: [NSLocalizedDescriptionKey: "Dock should be hidden when autohide is true and cursor is in center"])
            }

            // Move cursor to bottom edge
            desktop.cursor = CGPoint(x: 0.50, y: 0.97)
            desktop.movePointer(delta: CGSize(width: 0, height: 1)) // y >= 0.965 -> reveal
            guard desktop.isDockVisible == true else {
                throw NSError(domain: "Test", code: 37, userInfo: [NSLocalizedDescriptionKey: "Dock should reveal when cursor reaches bottom edge"])
            }

            // Reset autohide
            desktop.autohideDock = false
            guard desktop.isDockVisible == true else {
                throw NSError(domain: "Test", code: 38, userInfo: [NSLocalizedDescriptionKey: "Dock should remain visible when autohide is disabled"])
            }

            // 2. Fullscreen Frame calculation
            var testWin = DesktopSession.DesktopWindow(
                title: "TestFullscreenWin",
                normalizedFrame: CGRect(x: 0.20, y: 0.20, width: 0.50, height: 0.50),
                isMaximized: true
            )
            let maximizedFrame = desktop.effectiveFrame(for: testWin)
            guard maximizedFrame.width >= 0.98, maximizedFrame.origin.y >= 0.035 else {
                throw NSError(domain: "Test", code: 39, userInfo: [NSLocalizedDescriptionKey: "Maximized effective frame failed bounds check: \(maximizedFrame)"])
            }

            // 3. 8-Edge / Corner Resize Hit Testing
            testWin.isMaximized = false
            desktop.windows.append(testWin)
            defer { desktop.windows.removeAll(where: { $0.id == testWin.id }) }

            // Check bottom edge
            desktop.cursor = CGPoint(x: testWin.normalizedFrame.midX, y: testWin.normalizedFrame.maxY)
            guard desktop.resizeEdgeAtCursor() == .bottom else {
                throw NSError(domain: "Test", code: 40, userInfo: [NSLocalizedDescriptionKey: "Expected bottom resize edge hit, got \(String(describing: desktop.resizeEdgeAtCursor()))"])
            }

            // Check bottom-right corner
            desktop.cursor = CGPoint(x: testWin.normalizedFrame.maxX, y: testWin.normalizedFrame.maxY)
            guard desktop.resizeEdgeAtCursor() == .bottomRight else {
                throw NSError(domain: "Test", code: 41, userInfo: [NSLocalizedDescriptionKey: "Expected bottomRight resize corner hit, got \(String(describing: desktop.resizeEdgeAtCursor()))"])
            }

            // Check top edge (outside title bar traffic light zone)
            desktop.cursor = CGPoint(x: testWin.normalizedFrame.midX, y: testWin.normalizedFrame.minY)
            guard desktop.resizeEdgeAtCursor() == .top else {
                throw NSError(domain: "Test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Expected top resize edge hit, got \(String(describing: desktop.resizeEdgeAtCursor()))"])
            }

            results.append(TestResult(name: "Dock Auto-Hide, Fullscreen Bounds & 8-Edge Resize", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Dock Auto-Hide, Fullscreen Bounds & 8-Edge Resize", passed: false, message: error.localizedDescription))
        }

        // Test 16: Photos Store & Split Screen Assist verification
        do {
            let desktop = DesktopSession.shared
            let win1 = DesktopSession.DesktopWindow(title: "Photos", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
            let win2 = DesktopSession.DesktopWindow(title: "Notes", normalizedFrame: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.4))
            desktop.windows = [win1, win2]
            defer { desktop.windows.removeAll() }

            // 1. Snapping to leftHalf must activate Split Screen Assist on the rightHalf
            desktop.snapWindow(win1.id, to: .leftHalf)
            guard let assist = desktop.splitAssistState else {
                throw NSError(domain: "Test", code: 43, userInfo: [NSLocalizedDescriptionKey: "Split assist state was not activated on left half snap"])
            }
            guard assist.target == .rightHalf, assist.eligibleWindowIDs.contains(win2.id) else {
                throw NSError(domain: "Test", code: 44, userInfo: [NSLocalizedDescriptionKey: "Split assist target mismatch: \(assist.target)"])
            }

            // 2. Snapping the candidate window to rightHalf via assist
            desktop.snapWindow(win2.id, to: assist.target)
            desktop.dismissSplitAssist()
            guard desktop.splitAssistState == nil else {
                throw NSError(domain: "Test", code: 45, userInfo: [NSLocalizedDescriptionKey: "Split assist was not dismissed"])
            }
            let win2Frame = desktop.effectiveFrame(for: desktop.windows.first(where: { $0.id == win2.id })!)
            guard abs(win2Frame.origin.x - 0.506) < 0.01 else {
                throw NSError(domain: "Test", code: 46, userInfo: [NSLocalizedDescriptionKey: "Win2 frame not snapped to right half: \(win2Frame)"])
            }

            // 3. Verify DesktopPhotosStore state transitions
            let store = DesktopPhotosStore.shared
            store.selectedFilter = .favorites
            guard store.selectedFilter == .favorites else {
                throw NSError(domain: "Test", code: 47, userInfo: [NSLocalizedDescriptionKey: "PhotosStore filter change failed"])
            }
            store.select(assetID: "test-photo-123")
            guard store.selectedAssetID == "test-photo-123" else {
                throw NSError(domain: "Test", code: 48, userInfo: [NSLocalizedDescriptionKey: "PhotosStore selection failed"])
            }
            store.select(assetID: nil)
            guard store.selectedAssetID == nil else {
                throw NSError(domain: "Test", code: 49, userInfo: [NSLocalizedDescriptionKey: "PhotosStore deselect failed"])
            }

            results.append(TestResult(name: "Photos Store & Split Screen Assist Verification", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Photos Store & Split Screen Assist Verification", passed: false, message: error.localizedDescription))
        }

        return results
    }
}
