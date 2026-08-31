import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var session = RemoteSession()
    @StateObject private var desktop = DesktopSession.shared

    var body: some Scene {
        WindowGroup {
            DesktopAwareRootView()
                .environmentObject(session)
                .environmentObject(desktop)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}
