import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var session = RemoteSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
