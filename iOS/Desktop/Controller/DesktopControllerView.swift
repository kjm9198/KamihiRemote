import SwiftUI
import UIKit

/// The streamlined 3-area iPhone controller for Kamihi Desktop.
/// Area A: Compact Status/Header
/// Area B: Full Trackpad Surface with physics & gesture engine
/// Area C: Contextual Bottom Toolbar
struct DesktopControllerView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var engine = TrackpadEngine()
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    @State private var showLauncher = false
    @State private var showOverview = false
    @State private var showCommandPalette = false
    @State private var showTrackpadSettings = false
    @State private var showKeyboard = false
    @State private var takeoverWindowID: UUID?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Area A: Compact Header
                headerArea
                    .padding(.horizontal, KamihiTheme.Spacing.md)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Area B: Dominant Trackpad Surface
                trackpadArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                // Area C: Contextual Bottom Toolbar
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

            // Keyboard overlay dock if toggled
            if showKeyboard {
                VStack {
                    Spacer()
                    KeyboardOverlayDock()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
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
        }
    }

    // MARK: - Area A: Header
    private var headerArea: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                router.returnToChooser()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Modes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            // Active App Title & Status
            VStack(spacing: 1) {
                Text(desktop.activeWindow?.title ?? "Kamihi Desktop")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(desktop.isExternalDisplayConnected ? "Display Active" : "No External Display")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(desktop.isExternalDisplayConnected ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
            }

            Spacer(minLength: 4)

            // Battery / Settings icons
            HStack(spacing: 6) {
                if power.batteryLevel >= 0 {
                    HStack(spacing: 3) {
                        Image(systemName: (power.batteryState == .charging || power.batteryState == .full) ? "battery.100.bolt" : "battery.100")
                            .font(.system(size: 11))
                        Text(power.batteryPercentageText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }

                Button {
                    showTrackpadSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(7)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Area B: Trackpad
    private var trackpadArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            // Touch gesture receiver
            TrackpadGestureReceiver(engine: engine, desktop: desktop, settings: settings)
                .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))

            // Touch ripples
            ForEach(engine.ripples) { ripple in
                Circle()
                    .stroke(Color.cyan.opacity(ripple.opacity), lineWidth: 1.5)
                    .frame(width: ripple.radius * 2, height: ripple.radius * 2)
                    .position(ripple.point)
                    .allowsHitTesting(false)
            }

            // Drag lock indicator
            if engine.state == .dragLocked {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Drag Locked • Tap to Release")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .onTapGesture {
                        engine.unlockDrag(desktop: desktop)
                    }
                    Spacer()
                }
                .padding(.top, 12)
            }
        }
    }
}

private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

// MARK: - Trackpad Gesture Receiver (UIKit Touch Interceptor)
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

private final class TrackpadTouchInterceptorView: UIView {
    var engine: TrackpadEngine?
    var desktop: DesktopSession?
    var settings: TrackpadSettings?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        engine.handleTouchesBegan(touches, in: self, desktop: desktop, settings: settings)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        engine.handleTouchesMoved(touches, in: self, desktop: desktop, settings: settings)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop, let settings else { return }
        engine.handleTouchesEnded(touches, in: self, desktop: desktop, settings: settings)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let desktop else { return }
        engine.handleTouchesCancelled(touches, in: self, desktop: desktop)
    }
}

// MARK: - Trackpad Settings Sheet
struct TrackpadSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = TrackpadSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Pointer Dynamics") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text(String(format: "%.1fx", settings.pointerSensitivity))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.pointerSensitivity, in: 0.5...3.0, step: 0.1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Scroll Speed")
                            Spacer()
                            Text(String(format: "%.1fx", settings.scrollSpeed))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.scrollSpeed, in: 0.5...2.5, step: 0.1)
                    }

                    Toggle("Natural Scrolling", isOn: $settings.naturalScrolling)
                    Toggle("Tap to Click", isOn: $settings.tapToClick)
                    Toggle("Drag Lock", isOn: $settings.dragLock)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                }

                Section("Cursor Style") {
                    Picker("Style", selection: $settings.cursorStyle) {
                        ForEach(CursorStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Trackpad Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
