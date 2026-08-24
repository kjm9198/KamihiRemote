import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ZStack {
            AtmosphereBackground().allowsHitTesting(false)
            Group {
                if horizontalSizeClass == .regular {
                    padLayout
                } else if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                    portraitLayout
                } else {
                    landscapeLayout
                }
            }
        }
        .ignoresSafeArea()
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var padLayout: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusLabel
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(RemoteTab.allCases) { tab in
                        Button { session.selectedTab = tab } label: {
                            Label(tab.rawValue.capitalized, systemImage: symbol(for: tab))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(session.selectedTab == tab ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(session.selectedTab == tab ? 1 : 0.55))
                    }
                    Button { session.showsSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(10)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                Spacer()
            }
            .frame(width: 230)
            .padding(.leading, 24)
            .padding(.vertical, 28)
            screenBody
                .padding(20)
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            header.padding(.top, 18).padding(.horizontal, 24)
            screenBody.padding(.top, 8)
            statusLabel.padding(.bottom, 8)
            bottomBar.padding(.bottom, 24)
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header
                statusLabel
                Spacer()
                sideRail
            }
            .frame(width: 88)
            .padding(.leading, 16)
            .padding(.vertical, 20)
            screenBody
                .padding(.trailing, 16)
                .padding(.vertical, 12)
        }
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KAMIHI REMOTE")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(2.8)
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 8) {
                Circle()
                    .fill(session.isConnected ? Color.green.opacity(0.9) : Color.white.opacity(0.28))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(session.isConnected ? (session.hostName.isEmpty ? "Mac" : session.hostName) : session.statusText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            Text(session.telemetry.quality.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection \(session.isConnected ? "connected" : session.statusText), quality \(session.telemetry.quality.title)")
        .allowsHitTesting(false)
    }

    private var statusLabel: some View {
        Text(session.isConnected ? "connected" : session.statusText)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .allowsHitTesting(false)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(RemoteTab.allCases) { tab in
                tabButton(tab)
            }
            Button { session.showsSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 52, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 20)
    }

    private var sideRail: some View {
        VStack(spacing: 10) {
            ForEach(RemoteTab.allCases) { tab in
                Button { session.selectedTab = tab } label: {
                    Image(systemName: symbol(for: tab))
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .opacity(session.selectedTab == tab ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel(tab.rawValue)
            }
            Button { session.showsSettings = true } label: {
                Image(systemName: "gearshape").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func tabButton(_ tab: RemoteTab) -> some View {
        Button { session.selectedTab = tab } label: {
            Image(systemName: symbol(for: tab))
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .opacity(session.selectedTab == tab ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(session.selectedTab == tab ? .isSelected : [])
    }

    private func symbol(for tab: RemoteTab) -> String {
        switch tab {
        case .trackpad: return "hand.draw"
        case .slides: return "rectangle.on.rectangle"
        case .keyboard: return "keyboard"
        case .media: return "playpause"
        case .deck: return "square.grid.3x3"
        }
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
                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var precisionButton: some View {
        Button {
            session.precisionActive.toggle()
        } label: {
            Label(session.precisionActive ? "Precision" : "Pointer", systemImage: session.precisionActive ? "scope" : "cursorarrow")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Precision mode")
        .accessibilityValue(session.precisionActive ? "On" : "Off")
    }

    private var debugHUD: some View {
        let stats = session.engine.stats
        return VStack(alignment: .leading, spacing: 2) {
            Text("touch \(stats.touchActive ? "ON" : "off")  #\(stats.touchCount)")
            Text("MOVE \(stats.moveSent)  \(stats.movePerSecond)/s")
            Text("rtt \(session.telemetry.rttMilliseconds) ms")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.72))
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        copy.trackpadSize = size
        copy.isConnected = session.isConnected
        copy.isPrecision = session.precisionActive
        return copy
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
