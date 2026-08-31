import SwiftUI

@main
struct KamihiRemoteApp: App {
    @UIApplicationDelegateAdaptor(KamihiApplicationDelegate.self) private var appDelegate
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
