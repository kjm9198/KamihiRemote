import SwiftUI
import UIKit
import OSLog

private enum DesktopSmokeLog {
    static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")
}

@main
struct KamihiDesktopApp: App {
    @StateObject private var router = AppModeRouter()
    @StateObject private var desktop = DesktopSession.shared
    @StateObject private var desktopRecovery = DesktopRecoveryCoordinator.shared
    @StateObject private var hardwareInput = DesktopHardwareInputManager.shared

    init() {
        Task { @MainActor in
            // Hardware keyboards keep UIKit/SwiftUI's native text path, while
            // Bluetooth or USB-C mice feed Kamihi's virtual desktop pointer.
            DesktopHardwareInputManager.shared.start()

            #if DEBUG
            let servicesPassed = DesktopServicesTests.runSelfChecks()
            let refactor = DesktopRefactorTests.runSelfChecks()
            print("=== KAMIHI DESKTOP RUNTIME SELF-CHECKS ===")
            print("Desktop service checks: \(servicesPassed ? "PASSED ✓" : "FAILED ✗")")
            print("Desktop architecture checks: \(refactor.filter { $0.passed }.count)/\(refactor.count) passed")
            for result in refactor {
                print("  [\(result.passed ? "PASS" : "FAIL")] \(result.name): \(result.message)")
            }
            print("==========================================")
            #endif
        }
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
                    ZStack {
                        DesktopHardwareShortcutLayer()
                            .environmentObject(desktop)

                        // A physical keyboard is connected to the iPhone scene,
                        // while the desktop scene itself is intentionally passive.
                        // Capture only while a desktop field explicitly owns text
                        // focus, then route through the same safe app/WebKit paths
                        // as the phone keyboard.
                        DesktopHardwareKeyboardReceiver(
                            isEnabled: hardwareInput.isKeyboardConnected && desktop.wantsPhoneKeyboard,
                            desktop: desktop
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0.001)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
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
                    if router.currentMode != .externalDesktop || router.isDesktopLabActive {
                        router.selectMode(.externalDesktop)
                    }
                    _ = desktopRecovery.prepareForConnection(desktop: desktop)
                } else {
                    desktopRecovery.finishSession(desktop: desktop)
                }
            }
            .onChange(of: desktop.windows) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
            .onChange(of: desktop.activeWindowID) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                desktopRecovery.saveSnapshot(desktop: desktop, force: true)
                DesktopFeatureState.shared.saveSession(desktop: desktop)
            }
        }
    }
}
