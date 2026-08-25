import SwiftUI

struct KamihiV042RootView: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            V042Background()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let insets = geo.safeAreaInsets
                let contentSize = CGSize(
                    width: max(1, geo.size.width - insets.leading - insets.trailing),
                    height: max(1, geo.size.height - insets.top - insets.bottom)
                )
                let landscape = contentSize.width > contentSize.height * 1.05
                let immersiveController = session.selectedTab == .controller && landscape

                Group {
                    if immersiveController {
                        V042ControllerScreen(immersive: true)
                    } else if horizontalSizeClass == .regular && contentSize.width >= 700 {
                        tabletLayout(size: contentSize)
                    } else if landscape {
                        landscapeLayout(size: contentSize)
                    } else {
                        portraitLayout(size: contentSize)
                    }
                }
                .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
                .padding(.leading, insets.leading)
                .padding(.trailing, insets.trailing)
                .padding(.top, insets.top)
                .padding(.bottom, insets.bottom)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }

            if session.showsKeyboard {
                KeyboardMirrorDock()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: session.showsKeyboard)
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

    private func portraitLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("KAMIHI")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.52))
                Spacer(minLength: 8)
                V042ConnectionLabel()
                keyboardButton
                moreMenu
            }
            .padding(.horizontal, 14)
            .padding(.top, 7)

            screenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4)

            primaryNav(horizontal: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 7)
        }
        .frame(width: size.width, height: size.height)
    }

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 7) {
                Circle()
                    .fill(session.isConnected ? Color.green.opacity(0.92) : Color.white.opacity(0.28))
                    .frame(width: 8, height: 8)
                    .padding(.top, 2)
                    .accessibilityLabel(session.isConnected ? "Connected" : session.statusText)

                primaryNav(horizontal: false)

                Spacer(minLength: 4)

                keyboardButton
                moreMenu
            }
            .frame(width: 72)
            .padding(.vertical, 4)

            screenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: size.width, height: size.height)
    }

    private func tabletLayout(size: CGSize) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("KAMIHI")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.52))
                V042ConnectionLabel()
                primaryNav(horizontal: false)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    keyboardButton
                    moreMenu
                }
            }
            .frame(width: 184)
            .padding(12)

            screenBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var screenBody: some View {
        switch session.selectedTab {
        case .trackpad:
            V042TrackpadSurface(showDiagnostics: true)
        case .slides:
            V042PresentationScreen()
        case .deck:
            V042DeckScreen()
        case .controller:
            V042ControllerScreen(immersive: false)
        }
    }

    private var keyboardButton: some View {
        Button {
            session.showsKeyboard.toggle()
        } label: {
            Image(systemName: "keyboard")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(session.showsKeyboard ? 1 : 0.74))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Keyboard")
    }

    private var moreMenu: some View {
        Menu {
            Button { session.showsMedia = true } label: {
                Label("Media", systemImage: "playpause")
            }
            Button { session.showsSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .foregroundStyle(.white.opacity(0.76))
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("More controls")
    }

    private func primaryNav(horizontal: Bool) -> some View {
        Group {
            if horizontal {
                HStack(spacing: 0) {
                    ForEach(RemoteTab.allCases) { tab in navButton(tab, compact: false) }
                }
                .padding(5)
                .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                VStack(spacing: 3) {
                    ForEach(RemoteTab.allCases) { tab in navButton(tab, compact: true) }
                }
                .padding(5)
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
            .frame(width: compact ? 60 : nil)
            .frame(minHeight: compact ? 46 : 44)
            .opacity(selected ? 1 : 0.44)
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

private struct V042ConnectionLabel: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isConnected ? Color.green.opacity(0.92) : Color.white.opacity(0.28))
                .frame(width: 8, height: 8)
            Text(session.isConnected ? (session.hostName.isEmpty ? "Mac" : session.hostName) : session.statusText)
                .font(KamihiUI.captionFont)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.8))
        .accessibilityElement(children: .combine)
    }
}

struct V042TrackpadSurface: View {
    @EnvironmentObject private var session: RemoteSession
    var showDiagnostics: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TrackpadView(engine: session.engine)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Mac trackpad")

                DotFieldTouchAnimationView(state: fitted(session.engine.animation, size: geo.size))
                    .allowsHitTesting(false)

                if let banner = session.gestureBanner {
                    Text(banner)
                        .font(KamihiUI.bodyFont)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }

                if showDiagnostics && session.preferences.showDeveloperDiagnostics {
                    compactDebugHUD.allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var compactDebugHUD: some View {
        let debug = session.engine.debug
        let stats = session.engine.stats
        return VStack(alignment: .leading, spacing: 2) {
            Text("Touches \(stats.activeFingers) · \(debug.mode)")
            Text("dx \(Int(debug.cumulativeX)) · dy \(Int(debug.cumulativeY))")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.76))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

/// Original Kamihi visualization inspired by the idea of a responsive dot field: every
/// physical finger owns a dense radial constellation whose center is the exact UITouch
/// position. It does not copy Mousely artwork or assets.
struct DotFieldTouchAnimationView: View {
    let state: TouchAnimationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contactScale: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 30 : 1 / 60, paused: state.isFingerDown == false)) { timeline in
            ZStack {
                if state.isFingerDown {
                    Canvas { context, _ in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        for finger in state.fingers.prefix(4) {
                            drawDotField(context: &context, finger: finger, time: time)
                        }
                        drawGestureWake(context: &context)
                    }
                    .allowsHitTesting(false)

                    ForEach(Array(state.fingers.prefix(4))) { finger in
                        centerContact(for: finger)
                            .position(finger.point)
                            .transaction { $0.animation = nil }
                    }
                }
            }
        }
        .onChange(of: state.clickPulse) { _, _ in
            contactScale = 0.72
            withAnimation(.spring(response: 0.23, dampingFraction: 0.45)) {
                contactScale = 1
            }
        }
        .allowsHitTesting(false)
    }

    private func drawDotField(context: inout GraphicsContext, finger: TouchAnimationFinger, time: TimeInterval) {
        let count = max(state.fingerCount, 1)
        let radius: CGFloat = count == 1 ? 92 : (count == 2 ? 76 : 64)
        let spacing: CGFloat = count == 1 ? 9 : 10
        let cells = Int(ceil(radius / spacing))
        let speed = hypot(state.velocity.width, state.velocity.height)
        let speedEnergy = min(speed / 900, 1)
        let pulse = reduceMotion ? 1.0 : 0.94 + 0.06 * sin(time * 4.2 + Double(finger.id % 7))

        let vx = state.velocity.width
        let vy = state.velocity.height
        let magnitude = max(hypot(vx, vy), 1)
        let direction = CGVector(dx: vx / magnitude, dy: vy / magnitude)

        for gx in -cells...cells {
            for gy in -cells...cells {
                let localX = CGFloat(gx) * spacing
                let localY = CGFloat(gy) * spacing
                let distance = hypot(localX, localY)
                guard distance <= radius else { continue }

                let radial = max(0, 1 - distance / radius)
                let energy = pow(radial, 1.75)
                guard energy > 0.025 else { continue }

                let wake = reduceMotion ? 0 : energy * speedEnergy * 8
                let point = CGPoint(
                    x: finger.point.x - direction.dx * wake + localX,
                    y: finger.point.y - direction.dy * wake + localY
                )
                let dotSize = max(1.35, (1.6 + energy * (count == 1 ? 6.0 : 4.8)) * pulse)
                let opacity = min(0.88, 0.08 + Double(energy) * (count == 1 ? 0.78 : 0.62))
                let blueLift = Double(energy) * 0.22
                let color = Color(
                    red: 0.12 + blueLift * 0.35,
                    green: 0.48 + blueLift,
                    blue: 0.98
                ).opacity(opacity)

                let rect = CGRect(
                    x: point.x - dotSize / 2,
                    y: point.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }

    private func drawGestureWake(context: inout GraphicsContext) {
        guard state.fingerCount >= 3,
              state.modeName.contains("Swipe"),
              state.fingers.isEmpty == false
        else { return }

        let points = state.fingers.prefix(4).map(\.point)
        let x = points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        let y = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        let progress = state.gestureProgress
        let length = min(max(hypot(progress.width, progress.height), 30), 150)
        let angle = atan2(progress.height, progress.width)

        var path = Path(
            roundedRect: CGRect(x: x - length / 2, y: y - 4, width: length, height: 8),
            cornerRadius: 4
        )
        var transform = CGAffineTransform(translationX: -x, y: -y)
            .rotated(by: angle)
            .translatedBy(x: x, y: y)
        path = path.applying(transform)
        context.fill(path, with: .color(.cyan.opacity(0.10)))
    }

    private func centerContact(for finger: TouchAnimationFinger) -> some View {
        let size = contactSize
        return Circle()
            .fill(.clear)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(.white.opacity(state.isDragging ? 0.34 : 0.22)), in: .circle)
            .overlay {
                Circle().stroke(.white.opacity(0.18), lineWidth: 0.8)
            }
            .shadow(color: .cyan.opacity(0.16), radius: 7)
            .scaleEffect(state.fingerCount == 1 ? contactScale : 1)
            .accessibilityHidden(true)
    }

    private var contactSize: CGFloat {
        switch state.fingerCount {
        case 1: return state.isDragging ? 26 : 22
        case 2: return 24
        case 3: return 22
        default: return 20
        }
    }
}

struct V042PresentationScreen: View {
    @EnvironmentObject private var session: RemoteSession
    private var isLaser: Bool { session.pointerMode == .presentationLaser }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.05
            VStack(spacing: 8) {
                if landscape == false {
                    HStack {
                        Text("PRESENT")
                            .font(KamihiUI.titleFont)
                            .tracking(KamihiUI.labelTracking)
                            .foregroundStyle(.white.opacity(0.52))
                        Spacer()
                        pointerModeControl
                    }
                }

                HStack(spacing: 9) {
                    bigButton("Previous", "chevron.left") { send(.previous) }
                    bigButton("Next", "chevron.right") { send(.next) }
                }
                .frame(height: landscape ? min(102, geo.size.height * 0.29) : 90)

                ZStack(alignment: .topTrailing) {
                    V042TrackpadSurface(showDiagnostics: false)
                        .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                    if landscape {
                        pointerModeControl.padding(7)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 9) {
                    smallButton("Start", "play.fill") { send(.start) }
                    smallButton("Black", "rectangle.fill") { send(.black) }
                    smallButton("End", "xmark") { send(.end) }
                }
                .frame(height: 44)

                if landscape == false {
                    Picker("Profile", selection: $session.preferences.presentationProfile) {
                        ForEach(PresentationProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: session.preferences.presentationProfile) { _, _ in
                        session.preferences.save()
                    }
                }
            }
            .padding(9)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var pointerModeControl: some View {
        Picker("Pointer", selection: Binding(
            get: { isLaser ? 1 : 0 },
            set: { value in
                session.pointerMode = value == 1 ? .presentationLaser : .macCursor
                session.send(.laserVisible(value == 1))
            }
        )) {
            Text("Cursor").tag(0)
            Text("Laser").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .accessibilityLabel("Pointer mode")
    }

    private func send(_ action: PresentationAction) {
        session.send(.presentation(action: action, profile: session.preferences.presentationProfile))
        Haptics.slideChange()
    }

    private func bigButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 23, weight: .semibold))
                Text(title).font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusLarge))
        .accessibilityLabel(title)
    }

    private func smallButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
    }
}

struct V042DeckScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var showsAdd = false
    @State private var showsAppGallery = false
    @State private var editing: DeckButton?

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 9) {
                HStack {
                    Text("DECK")
                        .font(KamihiUI.titleFont)
                        .tracking(KamihiUI.labelTracking)
                        .foregroundStyle(.white.opacity(0.52))
                    Spacer()
                    Button {
                        showsAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Add deck action")
                    Button("Edit") { session.showsDeckEditor = true }
                        .font(KamihiUI.captionFont)
                        .foregroundStyle(.white.opacity(0.78))
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92, maximum: 148), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(session.deck) { button in
                            deckButton(button)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
            }
            .padding(9)

            if let feedback = session.deckActionFeedback {
                V042DeckFeedback(feedback: feedback)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: session.deckActionFeedback)
        .confirmationDialog("Choose an Action", isPresented: $showsAdd, titleVisibility: .visible) {
            Button("Application") {
                session.send(.requestAppList)
                showsAppGallery = true
            }
            Button("Shortcut") { add(.shortcut, title: "Shortcut", symbol: "command", payload: "cmd+c") }
            Button("Website") { add(.openURL, title: "Website", symbol: "globe", payload: "https://") }
            Button("System") { add(.system, title: "Mission Control", symbol: "rectangle.3.group", payload: SystemAction.missionControl.rawValue) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showsAppGallery) {
            MacAppGallery { app in
                add(.openApp, title: app.displayName, symbol: symbolForApp(app), payload: app.bundleIdentifier)
                showsAppGallery = false
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $session.showsDeckEditor) {
            DeckEditorSheet().environmentObject(session)
        }
        .sheet(item: $editing) { button in
            NavigationStack {
                DeckTileEditor(
                    button: Binding(
                        get: { session.deck.first(where: { $0.id == button.id }) ?? button },
                        set: { updated in
                            if let idx = session.deck.firstIndex(where: { $0.id == updated.id }) {
                                session.deck[idx] = updated
                                DeckButton.save(session.deck)
                            }
                        }
                    ),
                    apps: session.hostApps
                )
                .navigationTitle("Edit Tile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { editing = nil }
                    }
                }
            }
        }
    }

    private func deckButton(_ button: DeckButton) -> some View {
        Button {
            session.runDeck(button)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: button.symbol)
                    .font(.system(size: 22, weight: .semibold))
                Text(button.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .padding(6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
        .accessibilityLabel(button.title)
        .contextMenu {
            Button("Edit") { editing = button }
            Button("Remove", role: .destructive) { remove(button) }
        }
    }

    private func add(_ kind: DeckButton.Kind, title: String, symbol: String, payload: String) {
        let tile = DeckButton(id: UUID().uuidString, title: title, symbol: symbol, kind: kind, payload: payload)
        session.deck.append(tile)
        DeckButton.save(session.deck)
        Haptics.gesture()
    }

    private func remove(_ button: DeckButton) {
        session.deck.removeAll { $0.id == button.id }
        DeckButton.save(session.deck)
    }

    private func symbolForApp(_ app: HostAppEntry) -> String {
        switch app.bundleIdentifier {
        case "com.apple.Safari": return "safari"
        case "com.apple.finder": return "folder"
        case "com.apple.Music": return "music.note"
        default: return "app"
        }
    }
}

private struct V042DeckFeedback: View {
    let feedback: DeckActionFeedback

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(feedback.title).font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(feedback.message).font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch feedback.success {
        case .some(true): return "checkmark.circle.fill"
        case .some(false): return "exclamationmark.triangle.fill"
        case .none: return "arrow.up.circle"
        }
    }
}

struct V042ControllerScreen: View {
    @EnvironmentObject private var session: RemoteSession
    var immersive: Bool

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width * 1.05
            if immersive && portrait == false {
                VStack(spacing: 2) {
                    controllerMenuBar
                        .frame(height: 50)
                        .zIndex(20)

                    ControllerPadView(session: session, compact: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                ControllerPadView(session: session, compact: portrait)
                    .padding(8)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
        .onDisappear { session.sendController(.neutral) }
    }

    private var controllerMenuBar: some View {
        HStack {
            Spacer()
            Menu {
                Button {
                    leaveController(to: .trackpad)
                } label: {
                    Label("Trackpad", systemImage: "hand.draw")
                }
                Button {
                    leaveController(to: .slides)
                } label: {
                    Label("Presentation", systemImage: "rectangle.on.rectangle")
                }
                Button {
                    leaveController(to: .deck)
                } label: {
                    Label("Deck", systemImage: "square.grid.3x3")
                }
                Divider()
                Button {
                    session.showsKeyboard = true
                } label: {
                    Label("Keyboard", systemImage: "keyboard")
                }
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
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Controller menu")
            Spacer()
        }
    }

    private func leaveController(to tab: RemoteTab) {
        session.sendController(.neutral)
        session.selectedTab = tab
    }
}

private struct V042Background: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.13, green: 0.17, blue: 0.30),
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color.black
                ],
                center: .center,
                startRadius: 20,
                endRadius: 720
            )
            .opacity(0.95)
        }
    }
}
