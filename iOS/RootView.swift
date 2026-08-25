import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            mainContent
        }
        .sheet(isPresented: $session.showsSettings) {
            SettingsSheet().environmentObject(session)
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
            Group {
                if horizontalSizeClass == .regular && contentSize.width >= 700 {
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
            VStack(alignment: .leading, spacing: 16) {
                header
                ConnectionStatusChip()
                tabRail()
                Spacer(minLength: 0)
            }
            .frame(width: min(230, max(180, size.width * 0.28)))
            .padding(.leading, 12)
            .padding(.vertical, 12)
            screenBody
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func portraitLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                header
                Spacer(minLength: 8)
                ConnectionStatusChip()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            screenBody
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
                .padding(.bottom, 8)
        }
        .frame(width: size.width, height: size.height)
    }

    private func landscapeShell(size: CGSize) -> some View {
        let railWidth = min(76, max(56, size.width * 0.10))
        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                ConnectionStatusChip()
                Spacer(minLength: 8)
                tabRail()
                Spacer(minLength: 0)
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
            TrackpadCanvas()
        case .slides:
            PresentationScreen()
        case .keyboard:
            KeyboardScreen()
        case .media:
            MediaScreen()
        case .deck:
            DeckScreen()
        case .controller:
            ControllerScreen()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KAMIHI REMOTE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.62))
            Text(session.isConnected ? (session.hostName.isEmpty ? "Mac" : session.hostName) : session.statusText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kamihi Remote, \(session.isConnected ? "connected" : session.statusText)")
        .allowsHitTesting(false)
    }

    private var bottomBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(RemoteTab.allCases) { tab in
                    tabButton(tab)
                }
                Button { session.showsSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 48, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 12)
    }

    private func tabRail() -> some View {
        VStack(spacing: 8) {
            ForEach(RemoteTab.allCases) { tab in
                Button { session.selectedTab = tab } label: {
                    Image(systemName: symbol(for: tab))
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .opacity(session.selectedTab == tab ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(session.selectedTab == tab ? .isSelected : [])
            }
            Button { session.showsSettings = true } label: {
                Image(systemName: "gearshape").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityLabel("Settings")
        }
        .padding(8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func tabButton(_ tab: RemoteTab) -> some View {
        Button { session.selectedTab = tab } label: {
            Image(systemName: symbol(for: tab))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .opacity(session.selectedTab == tab ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(session.selectedTab == tab ? .isSelected : [])
    }

    private func symbol(for tab: RemoteTab) -> String {
        switch tab {
        case .trackpad: return "hand.draw"
        case .slides: return "rectangle.on.rectangle"
        case .keyboard: return "keyboard"
        case .media: return "playpause"
        case .deck: return "square.grid.3x3"
        case .controller: return "gamecontroller"
        }
    }
}

struct ModeShell<Controls: View>: View {
    @EnvironmentObject private var session: RemoteSession
    var pointerRatio: CGFloat = 0.56
    var compactPointerHeight: CGFloat = 168
    var showsPointerOverride: Bool? = nil
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.05
            let showPointer = showsPointerOverride ?? session.preferences.alwaysShowPointerPad
            Group {
                if showPointer == false {
                    VStack(spacing: 8) {
                        pointerToggleBar
                        controls()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if landscape {
                    HStack(spacing: 10) {
                        VStack(spacing: 8) {
                            pointerToggleBar
                            TrackpadCanvas()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: max(180, geo.size.width * pointerRatio))
                        controls()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 8) {
                        controls()
                            .frame(maxWidth: .infinity)
                        pointerToggleBar
                        TrackpadCanvas()
                            .frame(minHeight: 120, maxHeight: min(compactPointerHeight, max(130, geo.size.height * 0.36)))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var pointerToggleBar: some View {
        HStack {
            Button {
                session.preferences.alwaysShowPointerPad.toggle()
                session.preferences.save()
            } label: {
                Label(
                    session.preferences.alwaysShowPointerPad ? "Hide Pointer" : "Show Pointer",
                    systemImage: session.preferences.alwaysShowPointerPad ? "hand.raised.slash" : "hand.draw"
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(session.preferences.alwaysShowPointerPad ? "Hide pointer pad" : "Show pointer pad")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

struct TrackpadCanvas: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                TrackpadView(engine: session.engine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Mac trackpad")
                TouchAnimationView(state: fitted(session.engine.animation, size: size))
                    .allowsHitTesting(false)
                if session.preferences.showDeveloperDiagnostics {
                    debugHUD.allowsHitTesting(false)
                }
                VStack {
                    Spacer()
                    HStack {
                        precisionButton
                        if session.selectedTab != .trackpad {
                            pointerPadToggle
                        }
                        if session.selectedTab == .slides {
                            laserButton
                        }
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var precisionButton: some View {
        Button {
            session.precisionActive.toggle()
            session.pointerMode = .macCursor
        } label: {
            Label(session.precisionActive ? "Precision" : "Pointer", systemImage: session.precisionActive ? "scope" : "cursorarrow")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Mac cursor")
        .accessibilityValue(session.precisionActive ? "Precision on" : "Off")
    }

    private var pointerPadToggle: some View {
        Button {
            session.preferences.alwaysShowPointerPad.toggle()
            session.preferences.save()
        } label: {
            Label("Hide Pad", systemImage: "hand.raised.slash")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Hide pointer pad")
    }

    private var laserButton: some View {
        Button {
            session.pointerMode = session.pointerMode == .presentationLaser ? .macCursor : .presentationLaser
            session.send(.laserVisible(session.pointerMode == .presentationLaser))
        } label: {
            Label("Laser", systemImage: "circle.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(session.pointerMode == .presentationLaser ? .red : .white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Presentation laser")
        .accessibilityValue(session.pointerMode == .presentationLaser ? "On" : "Off")
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
            ForEach(Array(anim.fingers.prefix(4).enumerated()), id: \.element.id) { index, finger in
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
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .accessibilityHidden(true)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        let src = state.trackpadSize
        // Remap UIKit touch points into the SwiftUI overlay size so bubbles land on fingers.
        if src.width > 1, src.height > 1, size.width > 1, size.height > 1,
           abs(src.width - size.width) > 0.5 || abs(src.height - size.height) > 0.5 {
            let sx = size.width / src.width
            let sy = size.height / src.height
            copy.fingers = state.fingers.map { finger in
                var next = finger
                next.point = CGPoint(x: finger.point.x * sx, y: finger.point.y * sy)
                return next
            }
            copy.gestureProgress = CGSize(width: state.gestureProgress.width * sx, height: state.gestureProgress.height * sy)
            copy.velocity = CGSize(width: state.velocity.width * sx, height: state.velocity.height * sy)
        }
        copy.trackpadSize = size
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
                Text(session.isConnected ? "Connected" : session.statusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
