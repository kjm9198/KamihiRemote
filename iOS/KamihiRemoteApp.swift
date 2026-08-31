import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var session = RemoteSession()
    @StateObject private var desktop = DesktopSession.shared

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
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}
