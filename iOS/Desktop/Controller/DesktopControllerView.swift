import SwiftUI
import UIKit

/// iPhone control surface for Kamihi Desktop.
/// The phone is intentionally a full-screen trackpad. Keyboard and More are the
/// only persistent controls; every secondary action stays behind More.
struct DesktopControllerView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var engine = TrackpadEngine()
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var featureState = DesktopFeatureState.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("desktop.controller.controlsLeading") private var controlsLeading = false

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
        ZStack {
            KamihiTheme.surface.ignoresSafeArea()
            fullTrackpadLayout
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

    /// Only two thumb targets float above the trackpad. They stay at the
    /// thumb-reachable bottom edge (and can swap sides) while status, app
    /// switching, settings, capture and takeover remain discoverable in More.
    private var fullTrackpadLayout: some View {
        ZStack {
            trackpadSurface(cornerRadius: 0)
                .ignoresSafeArea()

            VStack {
                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if !controlsLeading { Spacer(minLength: 0) }

                    Button {
                        setKeyboardVisible(!showKeyboard)
                    } label: {
                        Image(systemName: "keyboard")
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
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
                    .accessibilityValue(desktop.activeWindow?.title ?? "No active window")
                    .accessibilityHint("Opens apps, windows, workspaces, status, settings, and other controls.")

                    if controlsLeading { Spacer(minLength: 0) }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var moreControllerActions: some View {
        Button(action: {}) {
            Label(
                desktop.activeWindow?.title ?? "Kamihi Desktop",
                systemImage: desktop.isExternalDisplayConnected ? "display" : "display.trianglebadge.exclamationmark"
            )
        }
        .disabled(true)

        Button(action: {}) {
            Label(
                desktop.isExternalDisplayConnected ? "External display connected" : "Desktop Lab / waiting",
                systemImage: desktop.isExternalDisplayConnected ? "checkmark.circle" : "clock"
            )
        }
        .disabled(true)

        Divider()

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

        Menu {
            ForEach(DesktopFeatureState.Workspace.allCases) { workspace in
                Button {
                    switchWorkspace(workspace)
                } label: {
                    if workspace == featureState.workspace {
                        Label(workspace.rawValue, systemImage: "checkmark.circle.fill")
                    } else {
                        Label(workspace.rawValue, systemImage: workspace.icon)
                    }
                }
                .disabled(workspace == featureState.workspace)
            }
        } label: {
            Label("Workspace: \(featureState.workspace.rawValue)", systemImage: "square.stack.3d.up.fill")
        }

        Divider()

        Button {
            controlsLeading.toggle()
            if settings.hapticsEnabled { Haptics.touchTap() }
        } label: {
            Label(
                controlsLeading ? "Move Controls to Right" : "Move Controls to Left",
                systemImage: controlsLeading ? "hand.point.right.fill" : "hand.point.left.fill"
            )
        }

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

    private func switchWorkspace(_ workspace: DesktopFeatureState.Workspace) {
        guard workspace != featureState.workspace else { return }
        setKeyboardVisible(false)
        featureState.setWorkspace(workspace, desktop: desktop)
        if settings.hapticsEnabled { Haptics.touchTap() }
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