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
                    Text("v0.5.0")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.55), lineWidth: 0.8))
                        .foregroundStyle(.cyan)
                }
                Spacer(minLength: 8)
                CompactConnectionLabel()
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
                    Text("v0.5.0")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }

                primaryNav(horizontal: false)

                Spacer(minLength: 4)

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
                    Text("v0.5.0")
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
        case .vibe:
            VibeHubScreen()
        case .trackpad:
            PolishedRemoteCombinedScreen()
        case .deck:
            DeckScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .codeKey:
            CodingKeyboardScreen()
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
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                VStack(spacing: 4) {
                    ForEach(RemoteTab.allCases) { tab in
                        navButton(tab, compact: true)
                    }
                }
                .padding(4)
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
                    .font(.system(size: compact ? 16 : 15, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(width: compact ? 64 : nil)
            .frame(minHeight: compact ? 44 : KamihiUI.controlHeight)
            .opacity(selected ? 1 : 0.46)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func symbol(for tab: RemoteTab) -> String {
        switch tab {
        case .vibe: return "bolt.fill"
        case .trackpad: return "hand.draw"
        case .deck: return "square.grid.3x3"
        case .codeKey: return "keyboard"
        case .controller: return "gamecontroller"
        }
    }
}

private struct CompactConnectionLabel: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        Button {
            if !session.isConnected {
                session.connectIfPossible()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.isConnected ? Color.green.opacity(0.9) : (session.connectionState == .connecting ? Color.yellow.opacity(0.9) : Color.white.opacity(0.35)))
                    .frame(width: 8, height: 8)
                Text(session.isConnected ? (session.hostName.isEmpty ? "Connected" : session.hostName) : (session.connectionState == .connecting ? "Connecting…" : session.statusText))
                    .font(KamihiUI.captionFont)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.10), in: Capsule())
            .foregroundStyle(.white.opacity(0.90))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Standalone pointer surface with exact canvas geometry.
struct PolishedTrackpadSurface: View {
    @EnvironmentObject private var session: RemoteSession
    var showDiagnostics: Bool = false

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
            Text("Touches: UIKit \(stats.activeFingers) · Engine \(debug.activeCount) · \(debug.mode)")
            Text("Centroid: (\(Int(debug.currentCentroid.x)), \(Int(debug.currentCentroid.y))) · Δ(\(Int(debug.cumulativeX)), \(Int(debug.cumulativeY)))")
            Text("Axis: \(debug.axis) · Dir: \(debug.direction) · [\(debug.isLocked ? "LOCKED" : "UNLOCKED")]")
            Text("Cmd: \(debug.lastCommand) · Last: \(tel.lastCommand)")
            if deck.title.isEmpty == false {
                Text("ACK: \(deck.title) [\(deck.executed ? "✓" : (deck.received ? "…" : "✗"))] \(deck.latencyMilliseconds.map { "\($0)ms" } ?? "") \(deck.message)")
            }
        }
        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        copy.trackpadSize = size
        copy.isConnected = session.isConnected
        copy.isPrecision = session.precisionActive
        return copy
    }
}

/// Unified Remote Screen: Combines full-surface Trackpad and inline Mac Keyboard dock on the same page.
struct PolishedRemoteCombinedScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var baseline = ""
    @State private var applyingRemote = false
    @State private var cmdActive = false
    @State private var optActive = false
    @State private var ctrlActive = false
    @State private var shiftActive = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                // Top area: Full multi-touch Trackpad canvas
                ZStack {
                    TrackpadView(engine: session.engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Mac trackpad")

                    DotFieldTouchView(state: fitted(session.engine.animation, size: geo.size))
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
                            .padding(.top, 10)
                            .allowsHitTesting(false)
                    }

                    if session.preferences.showDeveloperDiagnostics {
                        compactDebugHUD
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))

                // Bottom area: Integrated Mac Keyboard & Typing Dock
                VStack(spacing: 6) {
                    // Typing Input Row
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 15, weight: .medium))

                        TextField("Type to Mac…", text: $text)
                            .textFieldStyle(.plain)
                            .focused($focused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.return)
                            .onSubmit {
                                sendKey(code: 36)
                                text = ""
                                baseline = ""
                            }
                            .onChange(of: text) { _, newValue in
                                handleEdit(newValue)
                            }
                            .foregroundStyle(.white)
                            .font(.system(size: 13.5))

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
                            Button("Done") { focused = false }
                                .font(KamihiUI.captionFont.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.15), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))

                    // Mac Modifiers & Navigation Keys Row
                    HStack(spacing: 5) {
                        modifierButton("⌘", active: $cmdActive)
                        modifierButton("⌥", active: $optActive)
                        modifierButton("⌃", active: $ctrlActive)
                        modifierButton("⇧", active: $shiftActive)

                        keyButton("esc", code: 53)
                        keyButton("tab", code: 48)
                        keyButton("space", code: 49)
                        keyButton("⌫", code: 51)
                        keyButton("⏎", code: 36)
                    }

                    // Quick Actions & Arrows Row
                    HStack(spacing: 5) {
                        actionButton("⌘Z") { session.send(.shortcut("cmd+z")) }
                        actionButton("⌘C") { session.send(.shortcut("cmd+c")) }
                        actionButton("⌘V") { session.send(.shortcut("cmd+v")) }
                        actionButton("⌘Space") { session.send(.shortcut("cmd+space")) }

                        Spacer(minLength: 0)

                        arrowButton("arrow.left", code: 123)
                        arrowButton("arrow.up", code: 126)
                        arrowButton("arrow.down", code: 125)
                        arrowButton("arrow.right", code: 124)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var currentFlags: UInt64 {
        var flags: UInt64 = 0
        if cmdActive { flags |= 0x100000 }
        if shiftActive { flags |= 0x20000 }
        if optActive { flags |= 0x80000 }
        if ctrlActive { flags |= 0x40000 }
        return flags
    }

    private func sendKey(code: UInt16) {
        let f = currentFlags
        session.send(.keyDown(code: code, flags: f))
        session.send(.keyUp(code: code, flags: f))
        Haptics.click()
    }

    private func modifierButton(_ label: String, active: Binding<Bool>) -> some View {
        Button {
            active.wrappedValue.toggle()
            Haptics.click()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(active.wrappedValue ? Color.cyan.opacity(0.35) : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(active.wrappedValue ? Color.cyan : Color.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func keyButton(_ label: String, code: UInt16) -> some View {
        Button {
            sendKey(code: code)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.90))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            Haptics.click()
        }) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 7)
                .frame(minHeight: 28)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private func arrowButton(_ systemName: String, code: UInt16) -> some View {
        Button {
            sendKey(code: code)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 28)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.90))
        }
        .buttonStyle(.plain)
    }

    private var compactDebugHUD: some View {
        let debug = session.engine.debug
        let stats = session.engine.stats
        let tel = session.telemetry
        let deck = session.deckTrace
        return VStack(alignment: .leading, spacing: 2) {
            Text("TCP \(tel.tcpReady ? "✓" : "✗")  UDP \(tel.udpConfigured ? "✓" : "✗")  RTT \(tel.rttMilliseconds)ms")
            Text("Touches: UIKit \(stats.activeFingers) · Engine \(debug.activeCount) · \(debug.mode)")
            Text("Centroid: (\(Int(debug.currentCentroid.x)), \(Int(debug.currentCentroid.y))) · Δ(\(Int(debug.cumulativeX)), \(Int(debug.cumulativeY)))")
            Text("Axis: \(debug.axis) · Dir: \(debug.direction) · [\(debug.isLocked ? "LOCKED" : "UNLOCKED")]")
            Text("Cmd: \(debug.lastCommand) · Last: \(tel.lastCommand)")
            if deck.title.isEmpty == false {
                Text("ACK: \(deck.title) [\(deck.executed ? "✓" : (deck.received ? "…" : "✗"))] \(deck.latencyMilliseconds.map { "\($0)ms" } ?? "") \(deck.message)")
            }
        }
        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        copy.trackpadSize = size
        copy.isConnected = session.isConnected
        copy.isPrecision = session.precisionActive
        return copy
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
                        Button("Remote") { session.leaveController(to: .trackpad) }
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
