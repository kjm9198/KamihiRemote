import SwiftUI

struct TrackpadScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        RootView()
            .environmentObject(session)
    }
}
