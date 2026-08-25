import SwiftUI

/// Final v0.4 shell used by the app. It keeps all interactive content inside the
/// system safe area and avoids the old landscape sidebar overflowing below the phone.
struct KamihiPolishedRootView: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            PolishedAtmosphereBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height * 1.05
                let immersiveController = session.selectedTab == .controller && landscape

                Group {
                    if immersiveController {
                        PolishedControllerScreen(immersive: true)
                    } else if horizontalSizeClass == .regular && geo.size.width >= 700 {
                        tabletLayout
                    } else if landscape {
                        landscapeLayout
                    } else {
                        portraitLayout
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            if session.showsKeyboard {
                KeyboardOverlayDock()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.88), value: session.showsKeyboard)
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

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("KAMIHI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(KamihiUI.labelTracking)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("v0.4.2")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.55), lineWidth: 0.8))
                        .foregroundStyle(.cyan)
                }
                Spacer(minLength: 8)
                CompactConnectionLabel()
                keyboardButton
                moreMenu
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            polishedScreenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 6)

            primaryNav(horizontal: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 8) {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Circle()
                        .fill(session.isConnected ? Color.green.opacity(0.9) : Color.white.opacity(0.28))
                        .frame(width: 9, height: 9)
                        .padding(.top, 2)
                        .accessibilityLabel(session.isConnected ? "Connected" : session.statusText)
                    Text("v0.4.2")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }

                primaryNav(horizontal: false)

                Spacer(minLength: 4)

                keyboardButton
                moreMenu
            }
            .frame(width: 78)
            .padding(.vertical, 6)

            polishedScreenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var tabletLayout: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("KAMIHI")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(KamihiUI.labelTracking)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("v0.4.2")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.55), lineWidth: 0.8))
                        .foregroundStyle(.cyan)
                }
                CompactConnectionLabel()
                primaryNav(horizontal: false)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    keyboardButton
                    moreMenu
                }
            }
            .frame(width: 188)
            .padding(12)

            polishedScreenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
        }
    }

    @ViewBuilder
    private var polishedScreenBody: some View {
        switch session.selectedTab {
        case .trackpad:
            PolishedTrackpadSurface(showDiagnostics: true)
        case .keyboard:
            PolishedKeyboardScreen()
        case .deck:
            DeckScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .controller:
            PolishedControllerScreen(immersive: false)
        }
    }

    private var keyboardButton: some View {
        Button {
            session.showsKeyboard.toggle()
        } label: {
            Image(systemName: "keyboard")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: KamihiUI.controlHeight, height: KamihiUI.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(session.showsKeyboard ? 1 : 0.76))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Keyboard")
        .accessibilityAddTraits(session.showsKeyboard ? .isSelected : [])
    }

    private var moreMenu: some View {
        Menu {
            Button {
                session.showsMedia = true
            } label: {
                Label("Media", systemImage: "playpause")
            }
            Button {
                session.showsSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .frame(width: KamihiUI.controlHeight, height: KamihiUI.controlHeight)
                .foregroundStyle(.white.opacity(0.78))
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("More controls")
    }

    private func primaryNav(horizontal: Bool) -> some View {
        Group {
            if horizontal {
                HStack(spacing: 0) {
                    ForEach(RemoteTab.allCases) { tab in
                        navButton(tab, compact: false)
                    }
                }
                .padding(6)
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                VStack(spacing: 4) {
                    ForEach(RemoteTab.allCases) { tab in
                        navButton(tab, compact: true)
                    }
                }
                .padding(6)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
    }

    private func navButton(_ tab: RemoteTab, compact: Bool) -> some View {
        let selected = session.selectedTab == tab
        return Button {
            session.selectedTab = tab
            if tab == .controller { session.showsKeyboard = false }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol(for: tab))
                    .font(.system(size: compact ? 17 : 16, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(width: compact ? 64 : nil)
            .frame(minHeight: compact ? 47 : KamihiUI.controlHeight)
            .opacity(selected ? 1 : 0.46)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func symbol(for tab: RemoteTab) -> String {
        switch tab {
        case .trackpad: return "hand.draw"
        case .keyboard: return "keyboard"
        case .deck: return "square.grid.3x3"
        case .controller: return "gamecontroller"
        }
    }
}

private struct CompactConnectionLabel: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isConnected ? Color.green.opacity(0.9) : Color.white.opacity(0.28))
                .frame(width: 8, height: 8)
            Text(session.isConnected ? (session.hostName.isEmpty ? "Mac" : session.hostName) : session.statusText)
                .font(KamihiUI.captionFont)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.82))
        .accessibilityElement(children: .combine)
    }
}

/// Pointer surface with exact canvas geometry. Diagnostics are deliberately limited to
/// the main Trackpad tab so they can never cover Presentation again.
struct PolishedTrackpadSurface: View {
    @EnvironmentObject private var session: RemoteSession
    var showDiagnostics: Bool

    var body: some View {
        TrackpadBody(session: session, engine: session.engine, showDiagnostics: showDiagnostics)
    }
}

private struct TrackpadBody: View {
    @ObservedObject var session: RemoteSession
    @ObservedObject var engine: TouchInputEngine
    var showDiagnostics: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TrackpadView(engine: engine)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Mac trackpad")

                DotFieldTouchView(state: fitted(engine.animation, size: geo.size))
                    .allowsHitTesting(false)

                if let banner = session.gestureBanner ?? session.actionBanner {
                    Text(banner)
                        .font(KamihiUI.bodyFont)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }

                if showDiagnostics && session.preferences.showDeveloperDiagnostics {
                    compactDebugHUD
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var compactDebugHUD: some View {
        let debug = engine.debug
        let stats = engine.stats
        let tel = session.telemetry
        let deck = session.deckTrace
        return VStack(alignment: .leading, spacing: 2) {
            Text("TCP \(tel.tcpReady ? "✓" : "✗")  UDP \(tel.udpConfigured ? "✓" : "✗")  RTT \(tel.rttMilliseconds)ms")
            Text("HB \(Int(tel.lastHeartbeatAge * 1000))ms  sess \(tel.sessionShort)")
            Text("Touches \(stats.activeFingers) · \(debug.mode) · \(stats.movePerSecond)/s")
            Text("Last \(tel.lastCommand)")
            if deck.title.isEmpty == false {
                Text("DECK \(deck.title)")
                Text("sent \(deck.sent ? "✓" : "✗") recv \(deck.received ? "✓" : "✗") exec \(deck.executed ? "✓" : "✗") \(deck.latencyMilliseconds.map { "\($0)ms" } ?? "")")
                Text(deck.message)
            }
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .accessibilityHidden(true)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        copy.trackpadSize = size
        copy.isConnected = session.isConnected
        copy.isPrecision = session.precisionActive
        return copy
    }
}

/// Mousely-inspired interaction feedback without copying proprietary assets: small,
/// exact-position Liquid Glass contacts keyed to stable UITouch IDs.
struct PolishedTouchAnimationView: View {
    let state: TouchAnimationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clickScale: CGFloat = 1
    @State private var ripplePulse = 0

    var body: some View {
        ZStack {
            if state.isFingerDown {
                let fingers = Array(state.fingers.prefix(4))

                if fingers.count == 2 {
                    subtleBridge(fingers[0].point, fingers[1].point)
                }

                ForEach(fingers) { finger in
                    contact(for: finger, count: fingers.count)
                        .position(finger.point)
                        .transaction { $0.animation = nil }
                }
            }

            if ripplePulse > 0, let point = state.fingers.first?.point {
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 1.3)
                    .frame(width: 58, height: 58)
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: state.clickPulse) { _, _ in
            clickScale = 0.80
            ripplePulse += 1
            withAnimation(.spring(response: 0.25, dampingFraction: 0.48)) {
                clickScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                ripplePulse = 0
            }
        }
        .allowsHitTesting(false)
    }

    private func contact(for finger: TouchAnimationFinger, count: Int) -> some View {
        let size = orbSize(count: count)
        let material = Glass.regular.tint(.white.opacity(state.isDragging && count == 1 ? 0.34 : 0.23))
        return Circle()
            .fill(.clear)
            .frame(width: size, height: size)
            .glassEffect(material, in: .circle)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 0.8)
            }
            .shadow(color: Color(red: 0.45, green: 0.62, blue: 1.0).opacity(0.16), radius: 8)
            .scaleEffect(count == 1 ? clickScale : 1)
    }

    private func subtleBridge(_ a: CGPoint, _ b: CGPoint) -> some View {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let distance = hypot(b.x - a.x, b.y - a.y)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let opacity = max(0.04, 0.12 - min(distance / 1800, 0.08))

        return Capsule()
            .fill(.white.opacity(opacity))
            .frame(width: max(distance - 26, 8), height: 6)
            .blur(radius: reduceMotion ? 2 : 4)
            .rotationEffect(.radians(angle))
            .position(mid)
            .allowsHitTesting(false)
    }

    private func orbSize(count: Int) -> CGFloat {
        switch count {
        case 1: return state.isDragging ? 34 : 28
        case 2: return 36
        case 3: return 32
        default: return 30
        }
    }
}

struct PolishedKeyboardScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var baseline = ""
    @State private var applyingRemote = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                // Top half: full interactive Mac trackpad
                ZStack {
                    PolishedTrackpadSurface(showDiagnostics: false)
                        .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom half: clean typing dock without cluttered quick buttons
                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 18, weight: .medium))

                    TextField("Type to Mac…", text: $text)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.return)
                        .onSubmit {
                            session.send(.keyDown(code: 36, flags: 0))
                            session.send(.keyUp(code: 36, flags: 0))
                            text = ""
                            baseline = ""
                        }
                        .onChange(of: text) { _, newValue in
                            handleEdit(newValue)
                        }
                        .foregroundStyle(.white)
                        .accessibilityLabel("Text to the Mac")

                    if !text.isEmpty {
                        Button {
                            text = ""
                            baseline = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    if focused {
                        Button("Done") {
                            focused = false
                        }
                        .font(KamihiUI.captionFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15), in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(8)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func handleEdit(_ newValue: String) {
        guard applyingRemote == false else { return }
        if newValue == baseline { return }

        if newValue.hasPrefix(baseline) {
            let suffix = String(newValue.dropFirst(baseline.count))
            for character in suffix {
                if character == " " {
                    session.send(.keyDown(code: 49, flags: 0))
                    session.send(.keyUp(code: 49, flags: 0))
                } else if character == "\n" {
                    session.send(.keyDown(code: 36, flags: 0))
                    session.send(.keyUp(code: 36, flags: 0))
                } else {
                    session.send(.typeText(String(character)))
                }
            }
            baseline = newValue
            return
        }

        if baseline.hasPrefix(newValue), baseline.count > newValue.count {
            let deletes = baseline.count - newValue.count
            for _ in 0..<deletes {
                session.send(.keyDown(code: 51, flags: 0))
                session.send(.keyUp(code: 51, flags: 0))
            }
            baseline = newValue
            return
        }

        // Complete replacement
        for _ in 0..<baseline.count {
            session.send(.keyDown(code: 51, flags: 0))
            session.send(.keyUp(code: 51, flags: 0))
        }
        for character in newValue {
            if character == " " {
                session.send(.keyDown(code: 49, flags: 0))
                session.send(.keyUp(code: 49, flags: 0))
            } else if character == "\n" {
                session.send(.keyDown(code: 36, flags: 0))
                session.send(.keyUp(code: 36, flags: 0))
            } else {
                session.send(.typeText(String(character)))
            }
        }
        baseline = newValue
    }
}

struct PolishedControllerScreen: View {
    @EnvironmentObject private var session: RemoteSession
    var immersive: Bool

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width * 1.05
            ZStack(alignment: .top) {
                ControllerPadView(session: session, compact: portrait)
                    .padding(.horizontal, portrait ? 8 : 14)
                    .padding(.vertical, portrait ? 8 : 10)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                if immersive {
                    Menu {
                        Button("Trackpad") { session.leaveController(to: .trackpad) }
                        Button("Keyboard") { session.leaveController(to: .keyboard) }
                        Button("Deck") { session.leaveController(to: .deck) }
                        Divider()
                        Button("Keyboard") {
                            session.sendController(.neutral)
                            session.showsKeyboard = true
                        }
                        Button("Media") {
                            session.sendController(.neutral)
                            session.showsMedia = true
                        }
                        Button("Settings") {
                            session.sendController(.neutral)
                            session.showsSettings = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, 4))
                    .accessibilityLabel("Controller menu")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onDisappear {
            session.sendController(.neutral)
        }
    }
}

private struct PolishedAtmosphereBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.14, green: 0.18, blue: 0.31),
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color.black
                ],
                center: .center,
                startRadius: 20,
                endRadius: 700
            )
            .opacity(0.94)
        }
    }
}
