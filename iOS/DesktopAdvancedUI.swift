import SwiftUI
import UIKit

final class AdvancedExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        let root = AdvancedDesktopView()
            .environmentObject(DesktopSession.shared)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            let desktop = DesktopSession.shared
            desktop.externalDisplayDidConnect()
            if !DesktopFeatureState.shared.restoreSession(desktop: desktop) {
                DesktopFeatureState.shared.setWorkspace(.vibe, desktop: desktop)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task { @MainActor in
            DesktopFeatureState.shared.saveSession(desktop: DesktopSession.shared)
            DesktopSession.shared.externalDisplayDidDisconnect()
        }
        window = nil
    }
}

struct AdvancedDesktopAwareRootView: View {
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        Group {
            if desktop.isExternalDisplayConnected {
                AdvancedPhoneControllerView()
            } else {
                KamihiAppShell()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: desktop.isExternalDisplayConnected)
    }
}

struct AdvancedPhoneControllerView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @StateObject private var focusTimer = DesktopFocusTimer.shared
    @StateObject private var clipboard = DesktopClipboardStore.shared

    var body: some View {
        VStack(spacing: 0) {
            controlStrip
            ProductivityPhoneControllerView()
                .environmentObject(desktop)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $features.showCommandCenter) {
            DesktopCommandCenterView()
                .environmentObject(desktop)
        }
        .sheet(isPresented: $features.showQuickSettings) {
            DesktopQuickSettingsView()
                .environmentObject(desktop)
        }
        .sheet(isPresented: $features.showDisplayDiagnostics) {
            DesktopDiagnosticsPhoneView()
        }
        .onAppear {
            power.refresh()
            clipboard.captureIfChanged()
        }
        .onChange(of: features.uiScale) { _, _ in features.persistPreferences() }
        .onChange(of: features.cursorScale) { _, _ in features.persistPreferences() }
        .onChange(of: features.animationIntensity) { _, _ in features.persistPreferences() }
        .onChange(of: features.batterySaverOverride) { _, _ in features.persistPreferences() }
    }

    private var controlStrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    features.showCommandCenter = true
                } label: {
                    Label("Commands", systemImage: "command")
                }
                .buttonStyle(.borderedProminent)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(DesktopFeatureState.Workspace.allCases) { workspace in
                            workspaceButton(workspace)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Label(power.batteryPercentageText, systemImage: power.batteryState == .charging ? "battery.100percent.bolt" : "battery.75percent")
                    .font(.caption.monospacedDigit())

                Text(power.thermalText)
                    .font(.caption)
                    .foregroundStyle(power.thermalState >= .serious ? .orange : .secondary)

                if features.shouldConserveEnergy {
                    Label("Saver", systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if focusTimer.isRunning {
                    Label(focusTimer.formatted, systemImage: "timer")
                        .font(.caption.monospacedDigit())
                }

                Spacer()

                Button {
                    if focusTimer.isRunning { focusTimer.stop() }
                    else { focusTimer.start(minutes: 25) }
                } label: {
                    Image(systemName: focusTimer.isRunning ? "stop.circle" : "timer")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(focusTimer.isRunning ? "Stop focus timer" : "Start 25 minute focus timer")

                Button {
                    DesktopFeatureState.shared.saveSession(desktop: desktop)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Save desktop workspace")

                Button {
                    desktop.cycleWindow()
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Next desktop window")

                Button {
                    features.showQuickSettings = true
                } label: {
                    Image(systemName: "switch.2")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Desktop quick settings")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func workspaceButton(_ workspace: DesktopFeatureState.Workspace) -> some View {
        if features.workspace == workspace {
            Button {
                features.setWorkspace(workspace, desktop: desktop)
            } label: {
                Label(workspace.rawValue, systemImage: workspace.icon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                features.setWorkspace(workspace, desktop: desktop)
            } label: {
                Label(workspace.rawValue, systemImage: workspace.icon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }
}

struct AdvancedDesktopView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ProductivityDesktopView()
                    .environmentObject(desktop)
                    .blur(radius: features.privacyMode ? 26 : 0)
                    .scaleEffect(features.uiScale)

                if features.privacyMode {
                    privacyOverlay
                }

                if features.showDisplayDiagnostics {
                    diagnosticsOverlay(size: proxy.size)
                }

                VStack {
                    HStack(spacing: 10) {
                        Spacer()
                        if power.batteryLevel >= 0 {
                            Label(power.batteryPercentageText, systemImage: power.batteryState == .charging ? "battery.100percent.bolt" : "battery.75percent")
                        }
                        if features.shouldConserveEnergy {
                            Label("Power Saver", systemImage: "leaf.fill")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .background(.black)
    }

    private var privacyOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
            Text("Kamihi Desktop Hidden")
                .font(.title2.bold())
            Text("Turn off Privacy from the iPhone controller to continue.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private func diagnosticsOverlay(size: CGSize) -> some View {
        let metrics = DesktopDisplayMetrics(size: size, scale: 1)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Display Diagnostics", systemImage: "display.and.arrow.down")
                .font(.headline)
            Text("Output: \(Int(size.width)) × \(Int(size.height))")
            Text(String(format: "Aspect: %.2f", metrics.aspectRatio))
            Text("Profile: \(metrics.classification)")
            Text(String(format: "Recommended UI scale: %.2fx", metrics.recommendedScale))
            Divider()
            Text("RayNeo check: verify entire border is visible, text is sharp, pointer reaches all four corners, and no content is cropped.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 15, design: .monospaced))
        .padding(18)
        .frame(width: min(430, size.width * 0.42), alignment: .leading)
        .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25)))
    }
}

struct DesktopCommandCenterView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [DesktopCommand] {
        DesktopCommandCatalog.commands.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { command in
                Button {
                    command.action(desktop)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: command.icon)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.title)
                                .foregroundStyle(.primary)
                            Text(command.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Apps, windows and actions")
            .navigationTitle("Command Center")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct DesktopQuickSettingsView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    LabeledContent("UI Scale") {
                        Slider(value: $features.uiScale, in: 0.85...1.25, step: 0.05)
                            .frame(width: 180)
                    }
                    LabeledContent("Cursor Scale") {
                        Slider(value: $features.cursorScale, in: 0.8...1.8, step: 0.1)
                            .frame(width: 180)
                    }
                    LabeledContent("Animation") {
                        Slider(value: $features.animationIntensity, in: 0...1, step: 0.1)
                            .frame(width: 180)
                    }
                }

                Section("Power") {
                    Toggle("Force Desktop Battery Saver", isOn: $features.batterySaverOverride)
                    LabeledContent("Battery", value: power.batteryPercentageText)
                    LabeledContent("Thermal", value: power.thermalText)
                    LabeledContent("iOS Low Power Mode", value: power.lowPowerMode ? "On" : "Off")
                }

                Section("Workspace") {
                    Button("Save Current Workspace") { features.saveSession(desktop: desktop) }
                    Button("Restore Saved Workspace") { _ = features.restoreSession(desktop: desktop) }
                    Toggle("Privacy Screen", isOn: $features.privacyMode)
                    Button("Display Diagnostics") {
                        features.showDisplayDiagnostics = true
                        dismiss()
                    }
                }

                Section("Window Layout") {
                    Button("Top Left Quarter") { desktop.snapActiveTopLeft() }
                    Button("Top Right Quarter") { desktop.snapActiveTopRight() }
                    Button("Bottom Left Quarter") { desktop.snapActiveBottomLeft() }
                    Button("Bottom Right Quarter") { desktop.snapActiveBottomRight() }
                    Button("Left Third") { desktop.snapActiveThird(0) }
                    Button("Center Third") { desktop.snapActiveThird(1) }
                    Button("Right Third") { desktop.snapActiveThird(2) }
                }
            }
            .navigationTitle("Desktop Settings")
            .toolbar { Button("Done") { features.persistPreferences(); dismiss() } }
        }
    }
}

struct DesktopDiagnosticsPhoneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Physical display test") {
                    Label("Confirm RayNeo shows Kamihi Desktop, not mirrored iPhone UI", systemImage: "1.circle")
                    Label("Confirm all four corners and taskbar are visible", systemImage: "2.circle")
                    Label("Move pointer to every edge without clipping", systemImage: "3.circle")
                    Label("Open Vibe: ChatGPT + YouTube + Notes", systemImage: "4.circle")
                    Label("Type, scroll, right-click and snap windows", systemImage: "5.circle")
                    Label("Disconnect and reconnect without restart", systemImage: "6.circle")
                }

                Section("Power") {
                    LabeledContent("Battery", value: power.batteryPercentageText)
                    LabeledContent("Thermal", value: power.thermalText)
                    LabeledContent("Saver active", value: features.shouldConserveEnergy ? "Yes" : "No")
                }
            }
            .navigationTitle("RayNeo Test")
            .toolbar {
                Button("Close") {
                    features.showDisplayDiagnostics = false
                    dismiss()
                }
            }
        }
        .onAppear { features.showDisplayDiagnostics = true }
        .onDisappear { features.showDisplayDiagnostics = false }
    }
}
