import SwiftUI
import GameController

/// An original Kamihi setup guide based on public external-display workflows.
/// No permission prompts, pairing, telemetry, or network activity happen here.
struct DesktopSetupView: View {
    let onFinish: () -> Void
    let onLater: () -> Void
    var initialStep: DesktopSetupStep? = nil
    var persistsProgress = true

    @State private var step = DesktopSetupStep.welcome
    @State private var profile = DesktopLaunchProfile.selected
    @State private var keyboardSample = ""
    @State private var mouseReported = false
    @State private var keyboardReported = false
    @State private var showCalibration = false
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared
    @StateObject private var trackpad = TrackpadSettings.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AccessibilityFocusState private var headingFocused: Bool

    private let progress = DesktopSetupProgress()

    private var contentTypeSize: DynamicTypeSize {
        #if DEBUG
        if !persistsProgress && ProcessInfo.processInfo.arguments.contains("-KamihiSetupLargeText") {
            return .accessibility5
        }
        #endif
        return systemTypeSize
    }

    private var contentColorScheme: ColorScheme? {
        #if DEBUG
        if !persistsProgress && ProcessInfo.processInfo.arguments.contains("-KamihiSetupDark") {
            return .dark
        }
        if !persistsProgress && ProcessInfo.processInfo.arguments.contains("-KamihiSetupLight") {
            return .light
        }
        #endif
        return appearance.preferredColorScheme
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KAMIHI DESKTOP")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.tint)
                        Text(step.title)
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($headingFocused)
                            .accessibilityIdentifier("setup.heading")
                        ProgressView(value: Double(step.index + 1), total: Double(DesktopSetupStep.allCases.count))
                            .accessibilityLabel("Setup progress")
                            .accessibilityValue("Step \(step.index + 1) of \(DesktopSetupStep.allCases.count)")
                    }
                    page
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            // A new step starts at its heading even after the previous page was scrolled.
            .id(step)
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { navigationControls }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Set up later") { leaveSetup(finished: false) }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("setup.later")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(contentColorScheme)
        .environment(\.dynamicTypeSize, contentTypeSize)
        .onAppear {
            step = initialStep ?? progress.step
            refreshAccessories()
        }
        .onDisappear { display.showsSetupCalibration = false }
        .onChange(of: step) { _, value in
            if persistsProgress { progress.step = value }
            showCalibration = false
            display.showsSetupCalibration = false
            headingFocused = true
        }
        .onChange(of: showCalibration) { _, value in
            display.showsSetupCalibration = value && display.isConnected
        }
        .onChange(of: display.isConnected) { _, connected in
            display.showsSetupCalibration = connected && step == .display && showCalibration
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshAccessories() }
            display.showsSetupCalibration = phase == .active && display.isConnected && step == .display && showCalibration
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCMouseDidConnect)) { _ in refreshAccessories() }
        .onReceive(NotificationCenter.default.publisher(for: .GCMouseDidDisconnect)) { _ in refreshAccessories() }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in refreshAccessories() }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in refreshAccessories() }
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome:
            Image(systemName: "iphone.and.arrow.forward.outward")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .accessibilityHidden(true)
            Text("A bigger place for your everyday things.")
                .font(.title2.weight(.semibold))
            Text("Connect your iPhone to RayNeo glasses, a monitor or a TV. Keep your browsing, notes and documents in windows, with the phone as your trackpad and keyboard.")
            info("A desktop powered by your iPhone", "Kamihi has its own apps and browser windows. It does not run Mac apps or move other installed iPhone apps to the display.", icon: "apps.iphone")
            info("Start with what you have", "A mouse and keyboard are optional. You can finish this guide before connecting a display.", icon: "hand.draw")
        case .connection:
            connectionStatus
            info("RayNeo or a USB-C monitor", "Use a cable that supports video output. Connect the display and unlock your iPhone. A charging-only USB-C cable cannot carry a picture.", icon: "cable.connector")
            info("HDMI monitor or TV", "Use a compatible USB-C video adapter, choose the matching HDMI input, and connect power to the adapter if it supports charging.", icon: "tv")
            info("Lightning or AirPlay", "A compatible Lightning video adapter may provide an external scene. For AirPlay, connect using Screen Mirroring in Control Centre, then return here. Availability and latency depend on the device and receiver.", icon: "airplay.video")
            DisclosureGroup("No picture yet?") {
                Text("Check the display power and input. Reconnect the cable while your iPhone is unlocked and Kamihi is open. If you only see a mirror, try a video-capable cable or another adapter. This status changes when iOS supplies an external display scene.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            Text("You can continue while disconnected. Your desktop opens when a display becomes available.")
                .font(.footnote).foregroundStyle(.secondary)
        case .input:
            info("Your phone is a trackpad", "Move with one finger, tap to click, and scroll with two fingers. Use the Keyboard button for typing and the Apps button to open something new.", icon: "hand.draw.fill")
            info("Optional mouse and keyboard", "Pair accessories in iPhone Settings → Bluetooth, then return to Kamihi. You can keep using the phone controls at any time.", icon: "keyboard")
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Mouse reported by iOS", value: mouseReported ? "Available" : "Not reported")
                LabeledContent("Keyboard reported by iOS", value: keyboardReported ? "Available" : "Not reported")
                Text("Detection does not confirm pointer routing on the external screen. Try the accessory after opening your desktop.")
                    .font(.footnote).foregroundStyle(.secondary)
                TextField("Try typing here", text: $keyboardSample)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Keyboard practice, not saved")
                    .accessibilityIdentifier("setup.keyboardPractice")
                Text("Practice text stays on this screen and is not saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }.setupCard()
            VStack(alignment: .leading, spacing: 12) {
                Text("Pointer feel").font(.headline)
                ForEach(DesktopPointerProfile.allCases) { preset in
                    Button {
                        trackpad.applyPointerProfile(preset)
                    } label: {
                        HStack {
                            Text(preset.title)
                            Spacer()
                            if trackpad.matchingPointerProfile == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }.frame(minHeight: 44)
                    }
                    .accessibilityAddTraits(trackpad.matchingPointerProfile == preset ? [.isSelected] : [])
                }
            }.setupCard()
        case .display:
            connectionStatus
            if display.isConnected {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Native pixels", value: "\(Int(display.nativePixelSize.width)) × \(Int(display.nativePixelSize.height))")
                    LabeledContent("Refresh capability", value: "Up to \(display.maximumFramesPerSecond) Hz")
                    Text("Resolution is negotiated by iOS. The refresh capability is a reported maximum, not a measurement of the current refresh rate.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Show screen-fit guide", isOn: $showCalibration)
                    marginSlider("Left and right edges", value: $display.horizontalSafeMargin)
                    marginSlider("Top and bottom edges", value: $display.verticalSafeMargin)
                    Button("Reset margins") { display.resetCalibration() }
                        .frame(minHeight: 44)
                }.setupCard()
            } else {
                info("Adjust fit when you connect", "Real display dimensions and the screen-fit guide will appear after connection. Continue now, or return to Desktop & Display later.", icon: "rectangle.dashed")
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance").font(.headline)
                Picker("Appearance", selection: $appearance.colorTheme) {
                    ForEach(DesktopColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }.pickerStyle(.segmented)
                Text("Choose a comfortable look for your display. Start with zero margins, then move the edges inward only if they are clipped or hard to see.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.setupCard()
        case .privacy:
            info("Continue on iPhone", "If a sign-in page, consent form or file picker needs touch, choose Continue on iPhone. Complete the action on your phone, then return to the desktop.", icon: "iphone")
            info("Use your password manager", "Use the native password picker on your phone where the website supports it. Kamihi does not need an exported password file.", icon: "key.fill")
            info("Choose files when you need them", "Files opens the system picker when you import a document. Imported copies stay in Kamihi; your original files remain where you selected them.", icon: "folder.fill")
            info("Permissions when needed", "This guide asks for no permissions. iOS can ask later when you use a feature that needs protected access.", icon: "hand.raised.fill")
            Text("Some sites and protected video services restrict external playback or automated pointer input. Use the phone for supported native interaction; availability depends on the service.")
                .font(.footnote).foregroundStyle(.secondary)
        case .ready:
            Text("Choose an initial layout. You can open more apps and rearrange windows whenever you like.")
            ForEach(DesktopLaunchProfile.allCases) { option in
                Button { profile = option } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: option.systemImage).frame(width: 28).font(.title2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(option.title).font(.headline).foregroundStyle(.primary)
                            Text(option.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: profile == option ? "checkmark.circle.fill" : "circle")
                    }.frame(minHeight: 44).setupCard()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(profile == option ? [.isSelected] : [])
            }
            Label(display.isConnected ? "Display connected. Ready to open." : "Ready to connect whenever you are.", systemImage: display.isConnected ? "checkmark.circle" : "cable.connector")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var connectionStatus: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(display.isConnected ? "Display connected" : "Waiting for a display").font(.headline)
                Text(display.isConnected ? display.capabilitySummary : "Connect a video cable, or continue setup for later.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: display.isConnected ? "display" : "cable.connector")
                .foregroundStyle(display.isConnected ? Color.green : Color.secondary)
        }.setupCard()
            .accessibilityIdentifier("setup.displayStatus")
    }

    private var navigationControls: some View {
        HStack(spacing: 16) {
            if step != .welcome {
                Button("Back") { navigate(forward: false) }
                    .frame(minWidth: 64, minHeight: 48)
                    .accessibilityIdentifier("setup.back")
            }
            Button {
                if step == .ready { leaveSetup(finished: true) }
                else { navigate(forward: true) }
            } label: {
                Text(step == .ready ? "Open my desktop" : "Continue")
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            // The app accent is very pale; use a contrast-safe action color in both themes.
            .tint(Color(red: 0.05, green: 0.35, blue: 0.75))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .controlSize(.large)
            .accessibilityIdentifier("setup.continue")
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func navigate(forward: Bool) {
        let next = min(max(step.index + (forward ? 1 : -1), 0), DesktopSetupStep.allCases.count - 1)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            step = DesktopSetupStep.allCases[next]
        }
    }

    private func leaveSetup(finished: Bool) {
        display.showsSetupCalibration = false
        keyboardSample = ""
        if finished {
            if persistsProgress {
                progress.step = step
                guard progress.finish() else { return }
                DesktopLaunchProfile.selected = profile
            }
            onFinish()
        } else {
            if persistsProgress { progress.step = step }
            onLater()
        }
    }

    private func refreshAccessories() {
        mouseReported = !GCMouse.mice().isEmpty
        keyboardReported = GCKeyboard.coalesced != nil
    }

    private func info(_ title: String, _ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(.tint).frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.setupCard()
    }

    private func marginSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(Int((value.wrappedValue * 100).rounded()))%")
            Slider(value: value, in: 0...0.08, step: 0.005)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
        }
    }
}

private extension View {
    func setupCard() -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Pure SwiftUI calibration drawing; it never changes the negotiated hardware mode.
struct DesktopSetupCalibrationView: View {
    @ObservedObject private var display = ExternalDisplayCoordinator.shared

    var body: some View {
        GeometryReader { geometry in
            let insets = display.safeInsets(for: geometry.size)
            ZStack {
                Color(uiColor: .systemBackground)
                Rectangle().strokeBorder(Color.accentColor, lineWidth: 4)
                VStack {
                    HStack { Text("TOP LEFT"); Spacer(); Text("TOP RIGHT") }
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "display").font(.system(size: 48))
                        Text("Make all four edges visible").font(.largeTitle.bold())
                        Text("Adjust the margins on your iPhone.").font(.title2)
                        Text("The quick brown fox jumps over the lazy dog. 0123456789").font(.body)
                        Text(display.capabilitySummary).font(.headline.monospacedDigit())
                    }
                    Spacer()
                    HStack { Text("BOTTOM LEFT"); Spacer(); Text("BOTTOM RIGHT") }
                }.padding(24)
            }
            .padding(.top, insets.top).padding(.bottom, insets.bottom)
            .padding(.leading, insets.leading).padding(.trailing, insets.trailing)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
