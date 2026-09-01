import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var router = AppModeRouter()
    @StateObject private var session = RemoteSession()
    @StateObject private var desktop = DesktopSession.shared
    @StateObject private var desktopRecovery = DesktopRecoveryCoordinator.shared

    init() {
        #if DEBUG
        Task { @MainActor in
            let gesturePassed = GestureEngineTests.runSelfChecks()
            let servicesPassed = DesktopServicesTests.runSelfChecks()
            let refactor = DesktopRefactorTests.runSelfChecks()
            print("=== KAMIHI ON-DEVICE RUNTIME SELF-CHECKS ===")
            print("Gesture checks: \(gesturePassed ? "PASSED ✓" : "FAILED ✗")")
            print("Desktop service checks: \(servicesPassed ? "PASSED ✓" : "FAILED ✗")")
            print("Refactor architecture checks: \(refactor.filter { $0.passed }.count)/\(refactor.count) passed")
            for r in refactor {
                print("  [\(r.passed ? "PASS" : "FAIL")] \(r.name): \(r.message)")
            }
            print("============================================")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.currentMode {
                case .none:
                    ModeSelectionView()
                case .remoteMac:
                    // Kept only for legacy/debug launch arguments and integration regression testing.
                    // It is no longer exposed as a separate user-facing product in the normal app flow.
                    RemoteMacRootView()
                case .externalDesktop:
                    ExternalDesktopRootView()
                }
            }
            .environmentObject(router)
            .environmentObject(session)
            .environmentObject(desktop)
            .environmentObject(desktopRecovery)
            .statusBarHidden(false)
            .onChange(of: desktop.isExternalDisplayConnected) { _, connected in
                if connected {
                    _ = desktopRecovery.prepareForConnection(desktop: desktop)
                } else {
                    desktopRecovery.finishSession(desktop: desktop)
                }
            }
            .onChange(of: desktop.windows) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
        }
    }
}
