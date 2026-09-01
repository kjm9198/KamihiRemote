import SwiftUI

/// iPhone-side controls for external-display fidelity, RayNeo comfort calibration,
/// and the desktop's persisted System/Light/Dark appearance.
struct RayNeoDisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared

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
                    LabeledContent("Calibration", value: display.calibrationSummary)

                    if display.isConnected {
                        Label(
                            display.isLikelyRayNeo2DTarget
                                ? "Full-HD 16:9 class output detected"
                                : "Use the mode iOS negotiated; Kamihi will not fake 1080p or 120 Hz.",
                            systemImage: display.isLikelyRayNeo2DTarget ? "checkmark.circle.fill" : "info.circle"
                        )
                        .foregroundStyle(display.isLikelyRayNeo2DTarget ? .green : .secondary)
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
