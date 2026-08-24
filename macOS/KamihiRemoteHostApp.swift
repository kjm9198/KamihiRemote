import SwiftUI

@main
struct KamihiRemoteHostApp: App {
    @StateObject private var host = HostSession()

    var body: some Scene {
        Window("Kamihi Remote Host", id: "host") {
            HostView()
                .environmentObject(host)
                .frame(minWidth: 460, minHeight: 720)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 780)
    }
}
