import SwiftUI

/// Root view for the Kamihi Desktop product experience.
struct ExternalDesktopRootView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @State private var showDisplaySettings = false
    @State private var isSystemConstrained = Self.currentSystemConstraint

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
        .animation(transitionAnimation, value: router.isDesktopLabActive)
        .animation(transitionAnimation, value: desktop.isExternalDisplayConnected)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            refreshSystemConstraint()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            refreshSystemConstraint()
        }
        .sheet(isPresented: $showDisplaySettings) {
            RayNeoDisplaySettingsSheet()
        }
    }

    /// Root-mode/display transitions are cosmetic. Keep them snappy normally, but
    /// avoid spending extra animation work during Low Power Mode, serious/critical
    /// thermal pressure, or when the user has Reduce Motion enabled. The state is
    /// refreshed only from iOS notifications; there is no polling timer/display link.
    private var transitionAnimation: Animation? {
        guard !reduceMotion, !isSystemConstrained else { return nil }
        return KamihiTheme.Animation.standard
    }

    private static var currentSystemConstraint: Bool {
        let processInfo = ProcessInfo.processInfo
        let thermal = processInfo.thermalState
        return processInfo.isLowPowerModeEnabled || thermal == .serious || thermal == .critical
    }

    private func refreshSystemConstraint() {
        isSystemConstrained = Self.currentSystemConstraint
    }
}
