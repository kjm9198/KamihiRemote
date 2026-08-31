import SwiftUI

/// Root view for the Kamihi Desktop product experience.
struct ExternalDesktopRootView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        Group {
            if router.isDesktopLabActive {
                DesktopLabView()
            } else if desktop.isExternalDisplayConnected {
                DesktopControllerView()
            } else {
                NoDisplayConnectedView()
            }
        }
        .animation(KamihiTheme.Animation.standard, value: router.isDesktopLabActive)
        .animation(KamihiTheme.Animation.standard, value: desktop.isExternalDisplayConnected)
    }
}
