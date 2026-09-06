import SwiftUI
import OSLog

private enum DesktopSmokeLog {
    static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")
}

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
            .onAppear {
                #if DEBUG
                if router.isDesktopLabActive {
                    DesktopSmokeLog.logger.notice("KAMIHI_DESKTOP_LAB_READY")
                }
                #endif
            }
            .onChange(of: router.isDesktopLabActive) { _, isActive in
                #if DEBUG
                if isActive {
                    DesktopSmokeLog.logger.notice("KAMIHI_DESKTOP_LAB_READY")
                }
                #endif
            }
            .onChange(of: desktop.isExternalDisplayConnected) { _, connected in
                if connected {
                    // A real external-display connection owns the normal product
                    // flow. Promote the iPhone immediately into the full-screen
                    // Desktop controller instead of leaving it stranded on the
                    // entry screen while the monitor is already rendering Kamihi.
                    if router.currentMode != .externalDesktop || router.isDesktopLabActive {
                        router.selectMode(.externalDesktop)
                    }
                    _ = desktopRecovery.prepareForConnection(desktop: desktop)
                } else {
                    // Cable removal is a save boundary, never a reset. The phone
                    // stays in Desktop mode and the next connection resumes this OS.
                    desktopRecovery.finishSession(desktop: desktop)
                }
            }
            .onChange(of: desktop.windows) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
            .onChange(of: desktop.activeWindowID) { _, _ in
                // Focus is part of the user's desktop state too. Persist it even
                // when no window geometry changed so relaunch restores the same app.
                desktopRecovery.autosave(desktop: desktop)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                desktopRecovery.saveSnapshot(desktop: desktop, force: true)
                DesktopFeatureState.shared.saveSession(desktop: desktop)
            }
        }
    }
}
