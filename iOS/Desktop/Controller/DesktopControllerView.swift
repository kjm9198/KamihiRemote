import SwiftUI
import UIKit

/// The streamlined 3-area iPhone controller for Kamihi Desktop.
/// Area A: Compact Status/Header
/// Area B: Dominant Trackpad Surface
/// Area C: Contextual Bottom Toolbar
struct DesktopControllerView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var engine = TrackpadEngine()
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLauncher = false
    @State private var showOverview = false
    @State private var showCommandPalette = false
    @State private var showTrackpadSettings = false
    @State private var showKeyboard = false
    @State private var takeoverWindowID: UUID?

    var body: some View {
        ZStack {
            KamihiTheme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                headerArea
                    .padding(.horizontal, KamihiTheme.Spacing.md)
                    .padding(.top, 7)
                    .padding(.bottom, 6)

                trackpadArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                ContextualControllerToolbar(
                    engine: engine,
                    onOpenLauncher: { showLauncher = true },
                    onOpenOverview: { showOverview = true },
                    onOpenCommandPalette: { showCommandPalette = true },
                    onToggleKeyboard: { showKeyboard.toggle() },
                    onContinueOnPhone: { windowID in takeoverWindowID = windowID }
                )
                .padding(.bottom, 8)
            }

            if showKeyboard {
                VStack {
                    Spacer()
                    KeyboardOverlayDock()
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(20)
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
        }
        .onDisappear {
            engine.handleGestureCancelled(desktop: desktop)
        }
    }

    // MARK: - Area A: Header

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
            .accessibilityLabel("Back to modes")

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

    // MARK: - Area B: Trackpad

    private var trackpadArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                )

            TrackpadGestureReceiver(engine: engine, desktop: desktop, settings: settings)
                .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))

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
        .accessibilityHint("One finger moves the pointer. Two fingers scroll. Two finger tap opens the context menu. Three finger swipe up opens window overview.")
    }

    private var stateSymbol: String {
        switch engine.state {
        case .scrolling: return "arrow.up.and.down"
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
        case .resizing: return "Resizing window"
        case .idle: return "Ready"
        case .moving: return "Pointer"
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
        // `trackedTouches` contains all active fingers; UITouch locations update
        // in place as UIKit delivers movement samples.
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
                    Text("Tip: double-tap and hold a window title to move it. Double-tap and hold a window edge or corner to resize it. Three-finger swipe up opens Window Overview.")
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
