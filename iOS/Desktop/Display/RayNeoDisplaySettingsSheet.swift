import SwiftUI

/// iPhone-side controls for external-display fidelity and RayNeo comfort calibration.
/// The sliders only inset Kamihi's desktop canvas; they never request a fake resolution/refresh mode.
struct RayNeoDisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var display = ExternalDisplayCoordinator.shared

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("External Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
