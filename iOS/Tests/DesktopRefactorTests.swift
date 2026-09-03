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
                throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to return to startup profiles"])
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
            let extent = min(max(frame.width * 0.066, 0.020), 0.030)
            let gap = min(max(frame.width * 0.012, 0.004), 0.008)
            let trailing = min(max(frame.width * 0.018, 0.006), 0.012)

            let closeX = frame.maxX - trailing - extent / 2
            let maximizeX = closeX - extent - gap
            let minimizeX = maximizeX - extent - gap

            guard DesktopWindowChrome.action(at: CGPoint(x: closeX, y: y), in: frame) == .close,
                  DesktopWindowChrome.action(at: CGPoint(x: maximizeX, y: y), in: frame) == .maximizeRestore,
                  DesktopWindowChrome.action(at: CGPoint(x: minimizeX, y: y), in: frame) == .minimize,
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
                  abs(reversed.height + natural.height) < tolerance else {
                throw NSError(domain: "Test", code: 12, userInfo: [NSLocalizedDescriptionKey: "Horizontal/vertical scroll gains diverged"])
            }
            results.append(TestResult(name: "Two Axis Scroll Symmetry", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "Two Axis Scroll Symmetry", passed: false, message: error.localizedDescription))
        }

        return results
    }
}
