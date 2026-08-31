import Foundation
import CoreGraphics

/// Automated runtime self-checks for the Kamihi product refactor architecture.
public enum DesktopRefactorTests {
    public struct TestResult {
        public let name: String
        public let passed: Bool
        public let message: String
    }

    @MainActor
    public static func runSelfChecks() -> [TestResult] {
        var results: [TestResult] = []

        // Test 1: Mode Router Transitions
        do {
            let router = AppModeRouter()
            router.selectMode(.remoteMac)
            guard router.currentMode == .remoteMac else {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to switch to remoteMac"])
            }
            router.selectMode(.externalDesktop)
            guard router.currentMode == .externalDesktop else {
                throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to switch to externalDesktop"])
            }
            router.returnToChooser()
            guard router.currentMode == .none else {
                throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to return to chooser"])
            }
            results.append(TestResult(name: "AppModeRouter State Transitions", passed: true, message: "OK"))
        } catch {
            results.append(TestResult(name: "AppModeRouter State Transitions", passed: false, message: error.localizedDescription))
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

        return results
    }
}
