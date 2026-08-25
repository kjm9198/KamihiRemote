import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            mainContent
            if session.showsKeyboard {
                KeyboardOverlayDock()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: session.showsKeyboard)
        .sheet(isPresented: $session.showsSettings) {
            SettingsSheet().environmentObject(session)
        }
        .sheet(isPresented: $session.showsMedia) {
            NavigationStack {
                MediaScreen()
                    .environmentObject(session)
                    .navigationTitle("Media")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { session.showsMedia = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear { session.connectIfPossible() }
        .onChange(of: session.isConnected) { _, connected in
            session.engine.syncConnection(connected)
            if connected { Haptics.connect() }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let contentSize = CGSize(
                width: max(0, proxy.size.width - insets.leading - insets.trailing),
                height: max(0, proxy.size.height - insets.top - insets.bottom)
            )
            let landscape = contentSize.width > contentSize.height
            let immersiveController = session.selectedTab == .controller && landscape
            Group {
                if immersiveController {
                    ControllerScreen()
                } else if horizontalSizeClass == .regular && contentSize.width >= 700 {
                    padLayout(size: contentSize)
                } else if landscape {
                    landscapeShell(size: contentSize)
                } else {
                    portraitLayout(size: contentSize)
                }
            }
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
            .padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)
            .padding(.top, insets.top)
            .padding(.bottom, insets.bottom)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func padLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: KamihiUI.gap) {
                compactHeader
                ConnectionStatusChip()
                primaryNav(axis: .vertical)
                Spacer(minLength: 0)
                utilityColumn
            }
            .frame(width: min(220, max(168, size.width * 0.26)))
            .padding(.leading, KamihiUI.pad)
            .padding(.vertical, KamihiUI.pad)
            screenBody
                .padding(KamihiUI.pad)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func portraitLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                compactHeader
                Spacer(minLength: 8)
                ConnectionStatusChip()
                utilityRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            screenBody
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            primaryNav(axis: .horizontal)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .frame(width: size.width, height: size.height)
    }

    private func landscapeShell(size: CGSize) -> some View {
        let railWidth = min(84, max(64, size.width * 0.11))
        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                compactHeader
                    .frame(maxWidth: .infinity, alignment: .leading)
                ConnectionStatusChip()
                Spacer(minLength: 8)
                primaryNav(axis: .vertical)
                Spacer(minLength: 0)
                utilityColumn
            }
            .frame(width: railWidth)
            screenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var screenBody: some View {
        switch session.selectedTab {
        case .trackpad:
            TrackpadCanvas(chrome: .full)
        case .slides:
            PresentationScreen()
        case .deck:
            DeckScreen()
        case .controller:
            ControllerScreen()
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("KAMIHI")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(KamihiUI.labelTracking)
                .foregroundStyle(.white.opacity(0.55))
        }
        .accessibilityLabel("Kamihi Remote")
        .allowsHitTesting(false)
    }

    private var utilityRow: some View {
        HStack(spacing: 8) {
            utilityButton(systemName: "keyboard", label: "Keyboard", selected: session.showsKeyboard) {
                session.showsKeyboard.toggle()
            }
            utilityButton(systemName: "playpause", label: "Media") {
                session.showsMedia = true
            }
            utilityButton(systemName: "gearshape", label: "Settings") {
                session.showsSettings = true
            }
        }
    }

    private var utilityColumn: some View {
        VStack(spacing: 8) {
            utilityButton(systemName: "keyboard", label: "Keyboard", selected: session.showsKeyboard) {
                session.showsKeyboard.toggle()
            }
            utilityButton(systemName: "playpause", label: "Media") {
                session.showsMedia = true
            }
            utilityButton(systemName: "gearshape", label: "Settings") {
                session.showsSettings = true
            }
        }
    }

    private func utilityButton(systemName: String, label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: KamihiUI.controlHeight, height: KamihiUI.controlHeight)
                .opacity(selected ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func primaryNav(axis: Axis) -> some View {
        let tabs = RemoteTab.allCases
        return Group {
            if axis == .horizontal {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        primaryTabButton(tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                VStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        primaryTabButton(tab, vertical: true)
                    }
                }
                .padding(8)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
    }

    private func primaryTabButton(_ tab: RemoteTab, vertical: Bool = false) -> some View {
        let selected = session.selectedTab == tab
        return Button {
            session.selectedTab = tab
            if tab == .controller {
                session.showsKeyboard = false
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol(for: tab))
                    .font(.system(size: vertical ? 18 : 16, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: KamihiUI.controlHeight)
            .opacity(selected ? 1 : 0.48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func symbol(for tab: RemoteTab) -> String {
        switch tab {
        case .trackpad: return "hand.draw"
        case .slides: return "rectangle.on.rectangle"
        case .deck: return "square.grid.3x3"
        case .controller: return "gamecontroller"
        }
    }
}

/// Shared pointer surface — full mode or embedded region without duplicate chrome.
struct PointerSurface: View {
    @EnvironmentObject private var session: RemoteSession
    var chrome: TrackpadCanvas.Chrome = .minimal

    var body: some View {
        TrackpadCanvas(chrome: chrome)
    }
}

struct ModeShell<Controls: View>: View {
    @EnvironmentObject private var session: RemoteSession
    var pointerRatio: CGFloat = 0.56
    var compactPointerHeight: CGFloat = 168
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.05
            Group {
                if landscape {
                    HStack(spacing: KamihiUI.gap) {
                        PointerSurface(chrome: .minimal)
                            .frame(width: max(180, geo.size.width * pointerRatio))
                        controls()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: KamihiUI.gap) {
                        controls()
                            .frame(maxWidth: .infinity)
                        PointerSurface(chrome: .minimal)
                            .frame(minHeight: 120, maxHeight: min(compactPointerHeight, max(130, geo.size.height * 0.36)))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct TrackpadCanvas: View {
    enum Chrome {
        case full
        case minimal
    }

    @EnvironmentObject private var session: RemoteSession
    var chrome: Chrome = .full

    var body: some View {
        ZStack {
            TrackpadView(engine: session.engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityLabel("Mac trackpad")
                .overlay {
                    TouchAnimationView(state: fitted(session.engine.animation, size: session.engine.canvasSize))
                        .allowsHitTesting(false)
                }

            if let banner = session.gestureBanner {
                Text(banner)
                    .font(KamihiUI.bodyFont)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            if session.preferences.showDeveloperDiagnostics {
                debugHUD.allowsHitTesting(false)
            }
            if chrome == .full, session.preferences.showDeveloperDiagnostics {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        gestureProbe("MC", "Mission Control") { session.send(.system(.missionControl)) }
                        gestureProbe("Exposé", "App Exposé") { session.send(.system(.appExpose)) }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gestureProbe(_ title: String, _ accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(accessibility)
    }

    private var debugHUD: some View {
        let debug = session.engine.debug
        let stats = session.engine.stats
        let anim = session.engine.animation
        return VStack(alignment: .leading, spacing: 3) {
            Text("Active UIKit touches: \(stats.activeFingers)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text("Touch IDs:")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
            ForEach(Array(anim.fingers.prefix(4))) { finger in
                Text("  #\(finger.id)  x: \(Int(finger.point.x))  y: \(Int(finger.point.y))")
                    .font(.system(size: 10, design: .monospaced))
            }
            Text("GestureEngine fingers: \(debug.activeCount)")
                .font(.system(size: 10, design: .monospaced))
            Text("Mode: \(debug.mode)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(debug.mode.contains("Swipe") ? .cyan : .white)
            Text("Animation fingers: \(anim.fingerCount)")
                .font(.system(size: 10, design: .monospaced))
            Text("Cumulative: dx \(Int(debug.cumulativeX))  dy \(Int(debug.cumulativeY))")
                .font(.system(size: 10, design: .monospaced))
            Text("Intent: \(debug.scrollIntent)  MOVE: \(stats.moveSent)  RPS: \(session.telemetry.realtimePacketsPerSecond)")
                .font(.system(size: 10, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(10)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: KamihiUI.radiusSmall, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .accessibilityHidden(true)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        let canvas = size.width > 1 && size.height > 1 ? size : state.trackpadSize
        copy.trackpadSize = canvas.width > 1 ? canvas : CGSize(width: 390, height: 640)
        copy.isConnected = session.isConnected
        copy.isPrecision = session.precisionActive
        return copy
    }
}

struct ConnectionStatusChip: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var expanded = false

    var body: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.isConnected ? Color.green.opacity(0.9) : Color.white.opacity(0.28))
                    .frame(width: 8, height: 8)
                Text(session.isConnected
                     ? (session.hostName.isEmpty ? "Mac" : session.hostName)
                     : session.statusText)
                    .font(KamihiUI.captionFont)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(session.isConnected ? "Connected" : session.statusText)
        .popover(isPresented: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.hostName.isEmpty ? "Mac" : session.hostName).font(.headline)
                Text(session.telemetry.transport)
                if session.telemetry.rttMilliseconds > 0 {
                    Text("\(session.telemetry.rttMilliseconds) ms")
                }
                Text(session.telemetry.quality == .offline ? "Reconnecting" : "Stable")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct AtmosphereBackground: View {
    var body: some View {
        ZStack {
            Color.black
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.55, 0.48], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.07),
                    Color(red: 0.07, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color(red: 0.06, green: 0.07, blue: 0.13),
                    Color(red: 0.16, green: 0.20, blue: 0.34),
                    Color(red: 0.08, green: 0.07, blue: 0.16),
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color(red: 0.03, green: 0.04, blue: 0.08)
                ]
            )
            .blur(radius: 18)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
