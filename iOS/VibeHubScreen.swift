import SwiftUI

/// Vibe Mode Mission Control — Compact developer command HUD + integrated Trackpad.
struct VibeHubScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var commandInput = ""
    @State private var showsDictateSheet = false
    @State private var isDevServerRunning = true
    @State private var activeProject = "KamihiRemote"

    var body: some View {
        GeometryReader { geo in
            let trackpadHeight = max(180, geo.size.height * 0.46)
            let topHeight = max(180, geo.size.height - trackpadHeight - 12)

            VStack(spacing: 8) {
                // Top Mission Control HUD (Scrollable if needed on smaller screens)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        heroStatusRow
                        projectBar
                        aiCommandBar
                        quickActionsRow
                    }
                    .padding(.horizontal, KamihiUI.pad)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                }
                .frame(height: topHeight)

                // Bottom Integrated Trackpad Surface
                VStack(spacing: 4) {
                    HStack {
                        Text("TRACKPAD")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("1-finger move • 2-finger scroll • 3-finger Spaces")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, KamihiUI.pad)

                    PolishedTrackpadSurface(showDiagnostics: false)
                        .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, KamihiUI.pad)
                        .padding(.bottom, 4)
                }
                .frame(height: trackpadHeight)
            }
        }
        .sheet(isPresented: $showsDictateSheet) {
            DictatePromptSheet().environmentObject(session)
        }
    }

    private var heroStatusRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.isConnected ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(session.hostName.isEmpty ? "Mac" : session.hostName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            if !session.activeAppName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 10, weight: .semibold))
                    Text(session.activeAppName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(.white.opacity(0.85))
            }

            if session.telemetry.rttMilliseconds > 0 {
                Text("\(session.telemetry.rttMilliseconds)ms")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18), in: Capsule())
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private var projectBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isDevServerRunning ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(activeProject)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(isDevServerRunning ? ":3000" : "off")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isDevServerRunning ? .green : .red)
            }

            Spacer()

            Button {
                session.sendAcknowledged(.openURL("http://localhost:3000"), title: "Preview")
                Haptics.touchTap()
            } label: {
                Label("Preview", systemImage: "globe")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .foregroundStyle(.white.opacity(0.9))

            Button {
                isDevServerRunning.toggle()
                if isDevServerRunning {
                    session.send(.typeText("npm run dev\n"))
                } else {
                    session.send(.shortcut("ctrl+c"))
                }
                Haptics.touchTap()
            } label: {
                Image(systemName: isDevServerRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .foregroundStyle(isDevServerRunning ? .orange : .green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private var aiCommandBar: some View {
        HStack(spacing: 6) {
            TextField("Ask agent / run command…", text: $commandInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(.white)
                .submitLabel(.send)
                .onSubmit {
                    executeCommand()
                }

            Button {
                showsDictateSheet = true
                Haptics.touchTap()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Voice prompt")

            if !commandInput.isEmpty {
                Button {
                    executeCommand()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                quickChip("Git Status", icon: "arrow.triangle.branch") {
                    session.send(.typeText("git status\n"))
                }
                quickChip("Git Diff", icon: "doc.text.magnifyingglass") {
                    session.send(.typeText("git diff\n"))
                }
                quickChip("Desktop ←", icon: "arrow.left.square.fill") {
                    session.send(.system(.previousDesktop))
                }
                quickChip("Desktop →", icon: "arrow.right.square.fill") {
                    session.send(.system(.nextDesktop))
                }
                quickChip("Mission", icon: "rectangle.3.group.fill") {
                    session.send(.system(.missionControl))
                }
                quickChip("Screenshot", icon: "camera.viewfinder") {
                    session.send(.shortcut("cmd+shift+4"))
                }
            }
        }
    }

    private func quickChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.touchTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        session.send(.typeText(commandInput + "\n"))
        commandInput = ""
        Haptics.touchTap()
    }
}
