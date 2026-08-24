import SwiftUI

struct TrackpadScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.top, 18)
                    .padding(.horizontal, 24)

                trackpad
                    .padding(.top, 8)

                statusLabel
                    .padding(.bottom, 12)

                bottomBar
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $session.showsSettings) {
            SettingsSheet()
                .environmentObject(session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            let host = session.hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if host.isEmpty || !PairingSecret.isValid(session.pairingCode) {
                session.showsSettings = true
            } else {
                session.connectIfPossible()
            }
        }
        .onChange(of: session.udp.isConnected) { _, connected in
            session.engine.syncConnection(connected)
            if connected { Haptics.connect() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("KAMIHI REMOTE")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(.white.opacity(0.62))

            HStack(spacing: 8) {
                Text(session.udp.isConnected ? displayName : "Waiting")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Circle()
                    .fill(session.udp.isConnected ? Color.green.opacity(0.9) : Color.white.opacity(0.28))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 28)
        .allowsHitTesting(false)
    }

    private var trackpad: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                TrackpadView(engine: session.engine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                session.engine.handleSwiftUIDrag(location: value.location, in: size)
                            }
                            .onEnded { _ in
                                session.engine.handleSwiftUIDragEnded(in: size)
                            }
                    )

                TouchAnimationView(
                    state: fitted(session.engine.animation, size: size)
                )
                .allowsHitTesting(false)

                debugHUD
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var debugHUD: some View {
        let stats = session.engine.stats
        return VStack(alignment: .leading, spacing: 2) {
            Text("touch \(stats.touchActive ? "ON" : "off")  #\(stats.touchCount)")
            Text(String(format: "xy %.0f,%.0f  d %.2f,%.2f", stats.x, stats.y, stats.dx, stats.dy))
            Text("sent \(stats.packetsSent)  MOVE \(stats.moveSent)  \(stats.movePerSecond)/s")
            Text("udp MOVE \(session.udp.movePacketsSent)")
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.72))
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private var statusLabel: some View {
        Text(session.udp.isConnected ? "connected" : session.udp.statusText)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.bottom, 6)
            .allowsHitTesting(false)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(.trackpad, title: "Trackpad", systemImage: "hand.draw")
            tabButton(.slides, title: "Slides", systemImage: "rectangle.on.rectangle")
            Button {
                session.showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 64, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private func tabButton(_ tab: RemoteTab, title: String, systemImage: String) -> some View {
        Button {
            session.selectedTab = tab
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .opacity(session.selectedTab == tab ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(tab == .slides)
    }

    private var displayName: String {
        let name = session.udp.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Mac" }
        if name.lowercased().hasSuffix("mac") { return name }
        return "\(name)’s Mac"
    }

    private func fitted(_ state: TouchAnimationState, size: CGSize) -> TouchAnimationState {
        var copy = state
        copy.trackpadSize = size
        copy.isConnected = session.udp.isConnected
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
            RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.46, blue: 0.72).opacity(0.28),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
