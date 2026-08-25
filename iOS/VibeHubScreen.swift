import SwiftUI

/// Vibe Mode Mission Control — Developer command center for supervising and controlling your Mac.
struct VibeHubScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var commandInput = ""
    @State private var showsDictateSheet = false
    @State private var isDevServerRunning = true
    @State private var projectState = "Running :3000"
    @State private var activeProject = "KamihiRemote"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroStatusCard
                aiCommandBar
                projectLauncherCard
                quickActionsGrid
                quickWorkspaceJumpRow
            }
            .padding(.horizontal, KamihiUI.pad)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showsDictateSheet) {
            DictatePromptSheet().environmentObject(session)
        }
    }

    private var heroStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(session.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(session.hostName.isEmpty ? "MacBook Pro" : session.hostName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(session.telemetry.transport)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    if session.telemetry.rttMilliseconds > 0 {
                        Text("\(session.telemetry.rttMilliseconds)ms")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.cyan.opacity(0.18), in: Capsule())
                .foregroundStyle(.cyan)
            }

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .semibold))
                    Text(session.activeAppName.isEmpty ? "Finder" : session.activeAppName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Text("VIBE MODE ACTIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusLarge))
    }

    private var aiCommandBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI COMMAND BAR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.cyan.opacity(0.85))

            HStack(spacing: 8) {
                TextField("Ask Mac agent / run command…", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
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
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
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
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send command")
                }
            }

            // Quick suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    suggestionChip("Fix failing tests") { sendPrompt("Fix the failing tests in current project") }
                    suggestionChip("git status") { session.send(.typeText("git status\n")) }
                    suggestionChip("npm run dev") { session.send(.typeText("npm run dev\n")) }
                    suggestionChip("git commit") { sendPrompt("Commit current staged changes") }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusLarge))
    }

    private func suggestionChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.touchTap()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private var projectLauncherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE PROJECT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(activeProject)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isDevServerRunning ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(isDevServerRunning ? "localhost:3000 ●" : "Stopped")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(isDevServerRunning ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.25), in: Capsule())
            }

            HStack(spacing: 8) {
                Button {
                    // Open localhost in Safari on Mac
                    session.sendAcknowledged(.openURL("http://localhost:3000"), title: "Open Localhost")
                    Haptics.touchTap()
                } label: {
                    Label("Preview", systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(.white)

                Button {
                    isDevServerRunning.toggle()
                    if isDevServerRunning {
                        session.send(.typeText("npm run dev\n"))
                    } else {
                        session.send(.shortcut("ctrl+c"))
                    }
                    Haptics.touchTap()
                } label: {
                    Label(isDevServerRunning ? "Stop Server" : "Start Server", systemImage: isDevServerRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(isDevServerRunning ? .orange : .green)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusLarge))
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK WORKFLOW ACTIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.45))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                actionTile(title: "Git Status", symbol: "arrow.triangle.branch", color: .cyan) {
                    session.send(.typeText("git status\n"))
                }
                actionTile(title: "Git Diff", symbol: "doc.text.magnifyingglass", color: .cyan) {
                    session.send(.typeText("git diff\n"))
                }
                actionTile(title: "Desktop ←", symbol: "arrow.left.square.fill", color: .indigo) {
                    session.send(.system(.previousDesktop))
                }
                actionTile(title: "Desktop →", symbol: "arrow.right.square.fill", color: .indigo) {
                    session.send(.system(.nextDesktop))
                }
                actionTile(title: "Mission Control", symbol: "rectangle.3.group.fill", color: .indigo) {
                    session.send(.system(.missionControl))
                }
                actionTile(title: "Screenshot", symbol: "camera.viewfinder", color: .cyan) {
                    session.send(.shortcut("cmd+shift+4"))
                }
            }
        }
    }

    private func actionTile(title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.touchTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private var quickWorkspaceJumpRow: some View {
        HStack(spacing: 8) {
            jumpButton(title: "Trackpad", symbol: "hand.draw.fill", tab: .trackpad)
            jumpButton(title: "Deck", symbol: "square.grid.2x2.fill", tab: .deck)
            jumpButton(title: "CodeKey", symbol: "keyboard.fill", tab: .codeKey)
        }
    }

    private func jumpButton(title: String, symbol: String, tab: RemoteTab) -> some View {
        Button {
            session.selectedTab = tab
            Haptics.touchTap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        sendPrompt(commandInput)
        commandInput = ""
        Haptics.touchTap()
    }

    private func sendPrompt(_ text: String) {
        session.send(.typeText(text + "\n"))
    }
}
