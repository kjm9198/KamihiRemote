import SwiftUI

/// Root view for the Kamihi Desktop product experience.
struct ExternalDesktopRootView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @State private var showDisplaySettings = false

    var body: some View {
        Group {
            if router.isDesktopLabActive {
                DesktopLabView()
            } else if desktop.isExternalDisplayConnected {
                DesktopControllerView()
                    .overlay(alignment: .top) {
                        Button {
                            showDisplaySettings = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "display")
                                Text(display.capabilitySummary)
                                    .monospacedDigit()
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 9)
                        .accessibilityLabel("External display settings")
                        .accessibilityValue(display.capabilitySummary)
                    }
            } else {
                NoDisplayConnectedView()
            }
        }
        .animation(KamihiTheme.Animation.standard, value: router.isDesktopLabActive)
        .animation(KamihiTheme.Animation.standard, value: desktop.isExternalDisplayConnected)
        .sheet(isPresented: $showDisplaySettings) {
            RayNeoDisplaySettingsSheet()
        }
    }
}
