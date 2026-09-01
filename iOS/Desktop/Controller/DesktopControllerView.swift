import SwiftUI
import UIKit

/// iPhone control surface for Kamihi Desktop.
/// Normal mode prioritizes a readable desktop overview plus a compact trackpad;
/// Full Trackpad mode turns almost the whole phone into the gesture surface.
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
    @State private var takeoverWindowID: UUID?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                KamihiTheme.surface.ignoresSafeArea()

                if fullTrackpadMode {
                    fullTrackpadLayout
                } else {
                    normalLayout(in: geo.size)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showKeyboard {
                DesktopKeyboardInputBar {
                    setKeyboardVisible(false)
                }
                .environmentObject(desktop)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: showKeyboard)
        .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: fullTrackpadMode)
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
            if desktop.wantsPhoneKeyboard { showKeyboard = true }
        }
        .onChange(of: desktop.wantsPhoneKeyboard) { _, wantsKeyboard in
            if wantsKeyboard != showKeyboard {
                showKeyboard = wantsKeyboard
            }
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

    private var fullTrackpadLayout: some View {
        ZStack(alignment: .top) {
            trackpadSurface(cornerRadius: 0)
                .ignoresSafeArea()

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Full Trackpad")
                        .font(.caption.weight(.semibold))
                    Text(desktop.activeWindow?.title ?? "Kamihi Desktop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    setKeyboardVisible(!showKeyboard)
                } label: {
                    Image(systemName: "keyboard")
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Keyboard")

                Button {
                    fullTrackpadMode = false
                    if settings.hapticsEnabled { Haptics.touchTap() }
                } label: {
                    Image(systemName: "rectangle.compress.vertical")
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Exit Full Trackpad")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
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
        showKeyboard = visible
        if !visible {
            desktop.dismissPhoneKeyboardRequest()
        }
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

    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .submitLabel(.return)
                .onSubmit {
                    desktop.pressEnterInActiveDesktopField()
                }
                .onChange(of: text) { oldValue, newValue in
                    routeEdit(from: oldValue, to: newValue)
                }
                .accessibilityLabel("Type into \(desktop.activeWindow?.title ?? "desktop")")

            Button {
                desktop.pressEnterInActiveDesktopField()
            } label: {
                Image(systemName: "arrow.turn.down.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return")

            Button("Done") {
                focused = false
                onDismiss()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            text = ""
            Task { @MainActor in focused = true }
        }
    }

    private var placeholder: String {
        if desktop.activeWindow?.title == "Notes" { return "Type into note…" }
        return "Type on desktop…"
    }

    private func routeEdit(from oldValue: String, to newValue: String) {
        guard oldValue != newValue else { return }
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
