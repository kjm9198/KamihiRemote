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
            _ = GestureEngineTests.runSelfChecks()
            _ = DesktopServicesTests.runSelfChecks()
            _ = DesktopRefactorTests.runSelfChecks()
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
                    RemoteMacRootView()
                case .externalDesktop:
                    ExternalDesktopRootView()
                }
            }
            .environmentObject(router)
            .environmentObject(session)
            .environmentObject(desktop)
            .environmentObject(desktopRecovery)
            .preferredColorScheme(.dark)
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
