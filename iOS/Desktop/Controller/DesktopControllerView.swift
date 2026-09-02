import SwiftUI
import UIKit

/// iPhone control surface for Kamihi Desktop.
/// The full phone is the primary trackpad. Secondary desktop controls remain
/// available from More instead of consuming the main gesture surface.
struct DesktopControllerView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var engine = TrackpadEngine()
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("kamihi.desktop.controller.fullTrackpad") private var fullTrackpadMode = false

    @State private var showLauncher = false
    @State private var showOverview = false
    @State private var showCommandPalette = false
    @State private var showTrackpadSettings = false
    @State private var showKeyboard = false
    /// Keyboard input belongs to one explicit desktop window. If focus changes,
    /// close it rather than accidentally sending the next character elsewhere.
    @State private var keyboardWindowID: UUID?
    @State private var takeoverWindowID: UUID?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KamihiTheme.surface.ignoresSafeArea()

                fullTrackpadLayout
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showKeyboard {
                DesktopKeyboardInputBar(
                    windowID: keyboardWindowID,
                    onDismiss: { setKeyboardVisible(false) }
                )
                .environmentObject(desktop)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: showKeyboard)
        .sheet(isPresented: $showLauncher) {
            DesktopAppLauncherView()
                .environmentObject(desktop)
        }
        .sheet(isPresented: $showOverview) {
            DesktopWindowOverviewView()
                .environmentObject(desktop)
        }
        .sheet(isPresented: $showCommandPalette) {
            DesktopCommandPaletteView()
                .environmentObject(desktop)
        }
        .sheet(isPresented: $showTrackpadSettings) {
            TrackpadSettingsSheet()
        }
        .sheet(item: Binding(
            get: { takeoverWindowID.map { IdentifiableUUID(id: $0) } },
            set: { takeoverWindowID = $0?.id }
        )) { item in
            PhoneTakeoverView(windowID: item.id)
                .environmentObject(desktop)
        }
        .onAppear {
            power.refresh()
            engine.onThreeFingerSwipeUp = { showOverview = true }
            engine.onThreeFingerSwipeLeft = { desktop.cycleWindow(forward: false) }
            engine.onThreeFingerSwipeRight = { desktop.cycleWindow(forward: true) }
            if desktop.wantsPhoneKeyboard { setKeyboardVisible(true) }
        }
        .onChange(of: desktop.wantsPhoneKeyboard) { _, wantsKeyboard in
            if wantsKeyboard && !showKeyboard {
                setKeyboardVisible(true)
            } else if !wantsKeyboard && showKeyboard {
                setKeyboardVisible(false)
            }
        }
        .onChange(of: desktop.activeWindowID) { oldValue, newValue in
            guard oldValue != newValue, showKeyboard else { return }
            // A visible software keyboard should never silently redirect text
            // after a window switch.
            setKeyboardVisible(false)
        }
        .onDisappear {
            engine.handleGestureCancelled(desktop: desktop)
            setKeyboardVisible(false)
        }
    }

    private func normalLayout(in size: CGSize) -> some View {
        let previewHeight = min(size.width * 9.0 / 16.0, max(150, size.height * 0.34))
        let trackpadHeight = min(190, max(140, size.height * 0.25))

        return VStack(spacing: 0) {
            headerArea
                .padding(.horizontal, KamihiTheme.Spacing.md)
                .padding(.top, 7)
                .padding(.bottom, 6)

            DesktopControllerScreenPreview(desktop: desktop)
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .onTapGesture(count: 2) {
                    showLauncher = true
                    if settings.hapticsEnabled { Haptics.touchTap() }
                }
                .accessibilityHint("Double-tap to open the App Library")

            trackpadSurface(cornerRadius: KamihiTheme.Radius.lg)
                .frame(maxWidth: .infinity)
                .frame(height: trackpadHeight)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)

            Spacer(minLength: 0)

            ContextualControllerToolbar(
                engine: engine,
                onOpenLauncher: { showLauncher = true },
                onOpenOverview: { showOverview = true },
                onOpenCommandPalette: { showCommandPalette = true },
                onToggleKeyboard: { setKeyboardVisible(!showKeyboard) },
                onContinueOnPhone: { windowID in takeoverWindowID = windowID }
            )
            .padding(.bottom, 6)
        }
    }

    /// The phone is a dedicated trackpad by default. Everything that is not
    /// required while moving the pointer lives under More, so no tool rail steals
    /// working area or thumb reach.
    private var fullTrackpadLayout: some View {
        ZStack(alignment: .top) {
            trackpadSurface(cornerRadius: 0)
                .ignoresSafeArea()

            HStack(spacing: 8) {
                activeDesktopStatus

                Spacer(minLength: 8)

                Button {
                    setKeyboardVisible(!showKeyboard)
                } label: {
                    Image(systemName: "keyboard")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(showKeyboard ? "Hide Keyboard" : "Keyboard")
                .accessibilityHint("Types into the active desktop window.")
                .disabled(desktop.activeWindow == nil)

                Menu {
                    moreControllerActions
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("More Desktop Controls")
                .accessibilityHint("Opens apps, windows, settings, and other controls.")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    private var activeDesktopStatus: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(desktop.activeWindow?.title ?? "Kamihi Desktop")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(desktop.isExternalDisplayConnected ? "Trackpad" : "Desktop Lab / waiting")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(desktop.activeWindow?.title ?? "Kamihi Desktop"), \(desktop.isExternalDisplayConnected ? "trackpad ready" : "waiting for an external display")")
    }

    @ViewBuilder
    private var moreControllerActions: some View {
        Button {
            showLauncher = true
        } label: {
            Label("Apps", systemImage: "square.grid.2x2.fill")
        }

        Button {
            showOverview = true
        } label: {
            Label("Windows", systemImage: "rectangle.stack.fill")
        }

        Button {
            showCommandPalette = true
        } label: {
            Label("Commands", systemImage: "command")
        }

        Divider()

        Button {
            engine.isPrecisionMode.toggle()
            if settings.hapticsEnabled { Haptics.touchTap() }
        } label: {
            Label(
                engine.isPrecisionMode ? "Turn Off Precision Mode" : "Turn On Precision Mode",
                systemImage: engine.isPrecisionMode ? "scope" : "circle.dotted"
            )
        }

        Button {
            showTrackpadSettings = true
        } label: {
            Label("Trackpad Settings", systemImage: "slider.horizontal.3")
        }

        if let active = desktop.activeWindow {
            Button {
                takeoverWindowID = active.id
            } label: {
                Label("Continue on iPhone", systemImage: "iphone.and.arrow.forward")
            }
        }

        Button {
            let didPresent = DesktopCaptureService.shared.captureAndShare()
            if didPresent && settings.hapticsEnabled { Haptics.touchTap() }
        } label: {
            Label("Capture Desktop", systemImage: "camera.viewfinder")
        }

        Divider()

        Button(role: .destructive) {
            router.returnToChooser()
        } label: {
            Label("Exit Desktop", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                router.returnToChooser()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to startup profiles")

            VStack(alignment: .leading, spacing: 1) {
                Text(desktop.activeWindow?.title ?? "Kamihi Desktop")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(desktop.isExternalDisplayConnected ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(desktop.isExternalDisplayConnected ? "External display" : "Desktop Lab / waiting")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if power.batteryLevel >= 0 {
                HStack(spacing: 4) {
                    Image(systemName: (power.batteryState == .charging || power.batteryState == .full) ? "battery.100percent.bolt" : "battery.75percent")
                    Text(power.batteryPercentageText)
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Button {
                fullTrackpadMode = true
                if settings.hapticsEnabled { Haptics.touchTap() }
            } label: {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Full Trackpad")

            Button {
                showTrackpadSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trackpad settings")
        }
    }

    // MARK: - Trackpad

    private func trackpadSurface(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                )

            TrackpadGestureReceiver(engine: engine, desktop: desktop, settings: settings)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            ForEach(engine.ripples) { ripple in
                Circle()
                    .stroke(Color.primary.opacity(ripple.opacity * 0.45), lineWidth: 1)
                    .frame(width: ripple.radius * 2, height: ripple.radius * 2)
                    .position(ripple.point)
                    .allowsHitTesting(false)
            }

            if engine.state != .idle && engine.state != .moving {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: stateSymbol)
                        Text(stateLabel)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                }
                .allowsHitTesting(engine.state == .dragLocked)
                .onTapGesture {
                    if engine.state == .dragLocked {
                        engine.unlockDrag(desktop: desktop)
                    }
                }
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desktop trackpad")
        .accessibilityHint("One finger moves the pointer or drags a title bar. Two fingers scroll horizontally and vertically; two-finger drag on a window edge resizes. Two-finger tap opens the context menu. Three-finger swipe up opens Window Overview.")
    }

    private var stateSymbol: String {
        switch engine.state {
        case .scrolling: return "arrow.up.and.down.and.arrow.left.and.right"
        case .dragging: return "hand.draw"
        case .dragLocked: return "lock.fill"
        case .resizing: return "arrow.up.left.and.arrow.down.right"
        case .idle, .moving: return "circle.fill"
        }
    }

    private var stateLabel: String {
        switch engine.state {
        case .scrolling: return "Scrolling"
        case .dragging: return "Moving window"
        case .dragLocked: return "Drag locked • tap to release"
        case .resizing: return "Two-finger resize"
        case .idle: return "Ready"
        case .moving: return "Pointer"
        }
    }

    private func setKeyboardVisible(_ visible: Bool) {
        guard visible else {
            showKeyboard = false
            keyboardWindowID = nil
            desktop.dismissPhoneKeyboardRequest()
            return
        }

        guard let activeWindowID = desktop.activeWindowID else { return }
        keyboardWindowID = activeWindowID
        showKeyboard = true
    }
}

private struct DesktopControllerScreenPreview: View {
    @ObservedObject var desktop: DesktopSession

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KamihiTheme.AtmosphericBackground()

                if desktop.windows.filter({ !$0.isMinimized }).isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 24, weight: .light))
                        Text("Desktop ready")
                            .font(.caption.weight(.semibold))
                        Text("Double-tap here or use Apps to open something")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }

                ForEach(desktop.windows.filter { !$0.isMinimized }) { window in
                    let frame = desktop.effectiveFrame(for: window)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(desktop.activeWindowID == window.id ? Color.accentColor.opacity(0.26) : Color.primary.opacity(0.10))
                        .overlay(alignment: .topLeading) {
                            Text(window.title)
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(4)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(desktop.activeWindowID == window.id ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.15), lineWidth: 0.8)
                        )
                        .frame(width: max(8, frame.width * geo.size.width), height: max(8, frame.height * geo.size.height))
                        .position(x: frame.midX * geo.size.width, y: frame.midY * geo.size.height)
                }

                Circle()
                    .fill(Color.primary)
                    .frame(width: 5, height: 5)
                    .shadow(radius: 2)
                    .position(x: desktop.cursor.x * geo.size.width, y: desktop.cursor.y * geo.size.height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.8)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desktop overview")
    }
}

private struct DesktopKeyboardInputBar: View {
    @EnvironmentObject private var desktop: DesktopSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var isClearingAfterSubmit = false

    /// Captured at the moment the keyboard opens. Text is never redirected to a
    /// newly active window if the user switches windows while the keyboard is up.
    let windowID: UUID?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .focused($focused)
                .submitLabel(.return)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .onSubmit(submit)
                .onChange(of: text) { oldValue, newValue in
                    routeEdit(from: oldValue, to: newValue)
                }
                .accessibilityLabel("Type into \(desktop.activeWindow?.title ?? "desktop")")

            Button(action: submit) {
                Image(systemName: "arrow.turn.down.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return")

            Button("Done") {
                focused = false
                onDismiss()
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            text = ""
            focusKeyboard()
        }
    }

    private var placeholder: String {
        if desktop.activeWindow?.title == "Notes" { return "Type into note…" }
        return "Type on desktop…"
    }

    private var targetsCapturedWindow: Bool {
        guard let windowID else { return desktop.activeWindowID != nil }
        return desktop.activeWindowID == windowID
    }

    private func focusKeyboard() {
        // A second asynchronous focus pass survives the safe-area insertion
        // animation, which otherwise occasionally leaves the hardware keyboard
        // visible without a focused text field.
        Task { @MainActor in
            focused = true
            try? await Task.sleep(for: .milliseconds(120))
            focused = true
        }
    }

    private func submit() {
        guard targetsCapturedWindow else {
            onDismiss()
            return
        }
        desktop.pressEnterInActiveDesktopField()
        // The local TextField is only an input proxy. Clearing it after Return
        // keeps subsequent typing and backspace diffs short and deterministic;
        // suppress the local clearing change so it never deletes remote text.
        isClearingAfterSubmit = true
        text = ""
    }

    private func routeEdit(from oldValue: String, to newValue: String) {
        if isClearingAfterSubmit {
            isClearingAfterSubmit = false
            return
        }
        guard targetsCapturedWindow, oldValue != newValue else { return }

        let oldChars = Array(oldValue)
        let newChars = Array(newValue)
        var common = 0
        while common < min(oldChars.count, newChars.count), oldChars[common] == newChars[common] {
            common += 1
        }

        if oldChars.count > common {
            for _ in common..<oldChars.count {
                desktop.deleteBackwardInActiveDesktopField()
            }
        }

        if newChars.count > common {
            let inserted = String(newChars.dropFirst(common))
            desktop.typeIntoActiveDesktopField(inserted)
        }
    }
}

private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

// MARK: - Trackpad Gesture Receiver

private struct TrackpadGestureReceiver: UIViewRepresentable {
    let engine: TrackpadEngine
    let desktop: DesktopSession
    let settings: TrackpadSettings

    func makeUIView(context: Context) -> TrackpadTouchInterceptorView {
        let view = TrackpadTouchInterceptorView()
        view.engine = engine
        view.desktop = desktop
        view.settings = settings
        return view
    }

    func updateUIView(_ uiView: TrackpadTouchInterceptorView, context: Context) {
        uiView.engine = engine
        uiView.desktop = desktop
        uiView.settings = settings
    }
}

/// Tracks the complete active touch set instead of trusting UIKit callback
/// `touches.count`, which only represents touches that changed in that callback.
private final class TrackpadTouchInterceptorView: UIView {
    var engine: TrackpadEngine?
    var desktop: DesktopSession?
    var settings: TrackpadSettings?

    private var trackedTouches: Set<UITouch> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        isExclusiveTouch = true
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        trackedTouches.formUnion(touches)
        engine.handleGestureBegan(trackedTouches, in: self, desktop: desktop, settings: settings)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        engine.handleGestureMoved(trackedTouches, in: self, desktop: desktop, settings: settings)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        let beforeEnd = trackedTouches
        let remaining = max(beforeEnd.count - touches.count, 0)
        engine.handleGestureEnded(
            activeTouchesBeforeEnd: beforeEnd,
            endingTouches: touches,
            remainingTouchCount: remaining,
            in: self,
            desktop: desktop,
            settings: settings
        )
        trackedTouches.subtract(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop else { return }
        trackedTouches.removeAll()
        engine.handleGestureCancelled(desktop: desktop)
    }
}

// MARK: - Trackpad Settings Sheet

struct TrackpadSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = TrackpadSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Pointer") {
                    valueSlider(
                        title: "Speed",
                        value: $settings.pointerSensitivity,
                        range: 0.55...2.25,
                        step: 0.05,
                        format: "%.2fx"
                    )

                    valueSlider(
                        title: "Acceleration",
                        value: $settings.pointerAcceleration,
                        range: 0...2.0,
                        step: 0.1,
                        format: "%.1f"
                    )

                    Toggle("Tap to Click", isOn: $settings.tapToClick)
                    Toggle("Double-Tap Drag Lock", isOn: $settings.dragLock)
                    Toggle("Haptic Clicks", isOn: $settings.hapticsEnabled)
                }

                Section("Scrolling") {
                    valueSlider(
                        title: "Scroll Speed",
                        value: $settings.scrollSpeed,
                        range: 0.5...2.5,
                        step: 0.1,
                        format: "%.1fx"
                    )
                    Toggle("Natural Scrolling", isOn: $settings.naturalScrolling)
                    Toggle("Momentum", isOn: $settings.scrollMomentum)
                }

                Section("Pointer Style") {
                    Picker("Style", selection: $settings.cursorStyle) {
                        ForEach(CursorStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Text("One finger moves the pointer and can drag a title bar. Resizing requires two fingers while the pointer is on an edge or corner. Two fingers scroll in both axes. Three-finger swipe up opens Window Overview.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Trackpad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
