import SwiftUI

/// iPhone-side controls for external-display fidelity, RayNeo comfort calibration,
/// and the desktop's persisted System/Light/Dark appearance.
struct RayNeoDisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared
    @StateObject private var recovery = DesktopRecoveryCoordinator.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Desktop theme", selection: $appearance.colorTheme) {
                        ForEach(DesktopColorTheme.allCases) { theme in
                            Label(theme.title, systemImage: theme.symbol)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("System follows the iPhone appearance. Light and Dark override only Kamihi Desktop, including the external display and Desktop Lab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Connected Display") {
                    LabeledContent("Status", value: display.isConnected ? "Connected" : "Waiting")
                    LabeledContent("Native output", value: display.capabilitySummary)
                    LabeledContent("UIKit canvas", value: display.scaleSummary)
                    LabeledContent("Backing", value: display.backingSummary)
                    LabeledContent("Calibration", value: display.calibrationSummary)

                    if display.isConnected {
                        Label(
                            display.negotiatedModeSummary,
                            systemImage: display.isLikelyRayNeo2DTarget && display.isNativeBackingAligned
                                ? "checkmark.circle.fill"
                                : "info.circle"
                        )
                        .foregroundStyle(
                            display.isLikelyRayNeo2DTarget && display.isNativeBackingAligned
                                ? .green
                                : .secondary
                        )

                        if !display.isNativeBackingAligned {
                            Label(
                                "The native pixel backing does not currently match UIKit's reported native scale. Inspect the connected mode before judging sharpness.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        }

                        Text("iOS currently exposes a maximum of \(display.maximumFramesPerSecond) frames per second for this screen. Kamihi uses what iOS negotiates and never claims or forces 120 Hz when the screen reports less.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Connect an external display to read its real native backing resolution, UIKit scale, and refresh ceiling. Placeholder values are not treated as measured hardware results.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reconnect & Recovery") {
                    LabeledContent("Desktop state", value: recovery.displayHealth.label)

                    if let lastSnapshotDate = recovery.lastSnapshotDate {
                        LabeledContent("Last safety snapshot") {
                            Text(lastSnapshotDate, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if recovery.recoveredAfterInterruption {
                        Label("Kamihi restored the last safety snapshot after an interrupted desktop session.", systemImage: "arrow.clockwise.heart.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if display.isConnected {
                        Label("This display scene is connected normally. Unplug/replug should preserve the saved desktop session without creating a duplicate session.", systemImage: "cable.connector")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Reconnect the external display to verify that the same desktop returns. The recovery status above distinguishes a normal connection from an interruption restore.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("RayNeo Safe Area") {
                    calibrationSlider(
                        title: "Left / Right",
                        value: $display.horizontalSafeMargin
                    )
                    calibrationSlider(
                        title: "Top / Bottom",
                        value: $display.verticalSafeMargin
                    )

                    Text("Start at 0%. Increase only if the glasses crop an edge or the extreme corners are uncomfortable to see. Kamihi keeps the external scene at the native mode negotiated by iOS and moves only desktop content inward.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Reset to Full Canvas", systemImage: "arrow.counterclockwise") {
                        display.resetCalibration()
                    }
                }

                Section("Physical Air 4 Pro Check") {
                    Label("All four border edges are visible", systemImage: "rectangle.inset.filled")
                    Label("Pointer can reach every corner", systemImage: "cursorarrow.motionlines")
                    Label("Small text is sharp and comfortable", systemImage: "textformat.size")
                    Label("Unplug and reconnect restores the same desktop", systemImage: "cable.connector")

                    Text("Resolution, refresh rate, perceived latency and glasses overscan remain physical-device checks. A simulator cannot verify them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Desktop & Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private func calibrationSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...0.08, step: 0.005)
        }
    }
}
