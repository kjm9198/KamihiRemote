import SwiftUI

@main
struct KamihiDesktopApp: App {
    @StateObject private var router = AppModeRouter()
    @StateObject private var desktop = DesktopSession.shared
    @StateObject private var desktopRecovery = DesktopRecoveryCoordinator.shared

    init() {
        #if DEBUG
        Task { @MainActor in
            let servicesPassed = DesktopServicesTests.runSelfChecks()
            let refactor = DesktopRefactorTests.runSelfChecks()
            print("=== KAMIHI DESKTOP RUNTIME SELF-CHECKS ===")
            print("Desktop service checks: \(servicesPassed ? "PASSED ✓" : "FAILED ✗")")
            print("Desktop architecture checks: \(refactor.filter { $0.passed }.count)/\(refactor.count) passed")
            for result in refactor {
                print("  [\(result.passed ? "PASS" : "FAIL")] \(result.name): \(result.message)")
            }
            print("==========================================")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.currentMode {
                case .none:
                    ModeSelectionView()
                case .externalDesktop:
                    ExternalDesktopRootView()
                }
            }
            .environmentObject(router)
            .environmentObject(desktop)
            .environmentObject(desktopRecovery)
            .overlay {
                if router.currentMode == .externalDesktop {
                    DesktopHardwareShortcutLayer()
                        .environmentObject(desktop)
                }
            }
            .statusBarHidden(false)
            .onChange(of: desktop.isExternalDisplayConnected) { _, connected in
                if connected {
                    // A real external-display connection owns the normal product
                    // flow. Promote the iPhone immediately into the full-screen
                    // Desktop controller instead of leaving it stranded on the
                    // Enter Desktop screen while the monitor is already rendering
                    // Kamihi. This also keeps a fast reconnect seamless: the
                    // existing desktop/window state is recovered before the user
                    // starts interacting with the trackpad again.
                    if router.currentMode != .externalDesktop || router.isDesktopLabActive {
                        router.selectMode(.externalDesktop)
                    }
                    _ = desktopRecovery.prepareForConnection(desktop: desktop)
                } else {
                    // Do not bounce the user back through a mode/profile chooser on
                    // cable removal. Preserve the one-desktop state so reconnecting
                    // can resume directly into the trackpad controller.
                    desktopRecovery.finishSession(desktop: desktop)
                }
            }
            .onChange(of: desktop.windows) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
        }
    }
}
