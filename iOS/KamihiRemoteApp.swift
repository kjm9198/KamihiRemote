import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var session = RemoteSession()
    @StateObject private var desktop = DesktopSession.shared
    @StateObject private var desktopRecovery = DesktopRecoveryCoordinator.shared

    init() {
        #if DEBUG
        Task { @MainActor in
            _ = GestureEngineTests.runSelfChecks()
            _ = DesktopServicesTests.runSelfChecks()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AdvancedDesktopAwareRootView()
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
