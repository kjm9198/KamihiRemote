import SwiftUI
import UIKit

/// Compact Vibe mission control: project + agent context, hold-to-talk prompting,
/// reusable macros and an always-nearby trackpad without wasting vertical space.
struct VibeHubScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage("voiceAgentDestination") private var destinationRaw = VoiceAgentDestination.antigravity.rawValue
    @AppStorage("voiceAgentProjectID") private var selectedProjectID = "kamihi-remote"
    @AppStorage("vibeLastPrompt") private var lastPrompt = ""

    @State private var projects: [VoiceProject] = VoiceProjectStore.load()
    @State private var showsProjectManager = false
    @State private var showsProjectProfile = false
    @State private var promptText = ""
    @State private var isMicPressed = false
    @State private var isListening = false
    @State private var isSending = false
    @State private var vibeStatus = "Hold mic, release to send"
    @State private var recognizer = PromptSpeechRecognizer()
    @State private var isDevServerRunning = false

    private var destination: VoiceAgentDestination {
        VoiceAgentDestination(rawValue: destinationRaw) ?? .antigravity
    }

    private var selectedProject: VoiceProject? {
        guard selectedProjectID.isEmpty == false else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    private var projectProfile: VibeProjectProfile {
        VibeProjectProfileStore.load(projectID: selectedProject?.id)
    }

    private var projectTitle: String {
        selectedProject?.name ?? "Current App"
    }

    var body: some View {
        GeometryReader { geo in
            let trackpadHeight = max(170, geo.size.height * 0.52)

            VStack(spacing: 5) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        contextBar
                        composer
                        VibeMacroBar(promptText: $promptText, vibeStatus: $vibeStatus)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: .infinity)

                compactTrackpad
                    .frame(height: trackpadHeight)
            }
        }
        .sheet(isPresented: $showsProjectManager) {
            VoiceProjectManagerSheet(projects: $projects, selectedProjectID: $selectedProjectID)
        }
        .sheet(isPresented: $showsProjectProfile) {
            if let selectedProject {
                VibeProjectProfileSheet(project: selectedProject)
            }
        }
        .onAppear {
            projects = VoiceProjectStore.load()
            if selectedProjectID.isEmpty == false,
               projects.contains(where: { $0.id == selectedProjectID }) == false {
                selectedProjectID = projects.first?.id ?? ""
            }
        }
        .onDisappear {
            isMicPressed = false
            isListening = false
            recognizer.stop()
        }
    }

    // MARK: - Compact context

    @ViewBuilder
    private var contextBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    connectionControl
                    projectMenu
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 5) {
                    destinationMenu
                    Spacer(minLength: 0)
                    actionMenu
                }
            }
        } else {
            HStack(spacing: 5) {
                connectionControl

                projectMenu
                    .frame(maxWidth: .infinity)

                destinationMenu

                actionMenu
            }
        }
    }

    private var connectionControl: some View {
        Button {
            session.showsQuickConnect = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: session.isConnected ? "macbook" : "wifi.slash")
                    .font(.caption2.weight(.bold))
                Text(session.isConnected
                     ? (session.hostName.isEmpty ? "Mac" : session.hostName)
                     : "Connect")
                    .font(.caption2.weight(.semibold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(session.isConnected ? .green : .orange)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(session.isConnected
                            ? "Connected to \(session.hostName.isEmpty ? "Mac" : session.hostName)"
                            : "Not connected. Open connection setup")
    }

    private var projectMenu: some View {
        Menu {
            Button {
                selectedProjectID = ""
                isDevServerRunning = false
                Haptics.touchTap()
            } label: {
                Label("Current app only", systemImage: selectedProject == nil ? "checkmark" : "macwindow")
            }

            Divider()

            ForEach(projects) { project in
                Button {
                    selectedProjectID = project.id
                    isDevServerRunning = false
                    VoiceAgentRouter.switchWorkspace(to: project, destination: destination, session: session)
                    Haptics.touchTap()
                } label: {
                    HStack {
                        Text(project.name)
                        if project.id == selectedProjectID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                showsProjectManager = true
                Haptics.touchTap()
            } label: {
                Label("Manage Projects…", systemImage: "folder.badge.gearshape")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: selectedProject == nil ? "macwindow" : "folder.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
                Text(projectTitle)
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Project: \(projectTitle)")
    }

    private var destinationMenu: some View {
        Menu {
            ForEach(VoiceAgentDestination.allCases) { item in
                Button {
                    destinationRaw = item.rawValue
                    Haptics.touchTap()
                } label: {
                    Label(item.title, systemImage: item.symbol)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: destination.symbol)
                    .font(.caption2.weight(.bold))
                Text(destination.title)
                    .font(.caption2.weight(.semibold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.cyan)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Coding agent: \(destination.title)")
    }

    private var actionMenu: some View {
        Menu {
            Button {
                VibeProjectCommandRunner.openPreview(project: selectedProject, profile: projectProfile, session: session)
                Haptics.touchTap()
            } label: {
                Label("Open Preview", systemImage: "globe")
            }

            Button {
                if isDevServerRunning {
                    VibeProjectCommandRunner.stopFrontTerminalCommand(session: session)
                } else {
                    VibeProjectCommandRunner.runDev(project: selectedProject, profile: projectProfile, session: session)
                }
                isDevServerRunning.toggle()
                Haptics.touchTap()
            } label: {
                Label(isDevServerRunning ? "Stop Dev Command" : "Run Dev Command",
                      systemImage: isDevServerRunning ? "stop.fill" : "play.fill")
            }

            Button {
                VibeProjectCommandRunner.runTests(project: selectedProject, profile: projectProfile, session: session)
                Haptics.touchTap()
            } label: {
                Label("Run Tests", systemImage: "checkmark.seal.fill")
            }

            if let selectedProject {
                Button {
                    showsProjectProfile = true
                    Haptics.touchTap()
                } label: {
                    Label("Configure Vibe Actions…", systemImage: "slider.horizontal.3")
                }
            }

            Divider()

            Menu("Quick Prompts") {
                ForEach(CompactVibePreset.defaults) { preset in
                    Button {
                        usePrompt(preset.prompt)
                    } label: {
                        Label(preset.title, systemImage: preset.symbol)
                    }
                }

                if lastPrompt.isEmpty == false {
                    Divider()
                    Button {
                        usePrompt(lastPrompt)
                    } label: {
                        Label("Repeat Last", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.82))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Vibe actions")
    }

    // MARK: - Composer + hold-to-talk

    private var composer: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 6) {
                TextField(
                    "Tell \(destination.title) what to change…",
                    text: $promptText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .lineLimit(1...3)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .frame(minHeight: 48)
                .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(.white)
                .submitLabel(.send)
                .onSubmit { sendCurrentPrompt() }
                .accessibilityLabel("Vibe prompt")

                clipboardMenu

                if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                   isListening == false,
                   isMicPressed == false {
                    Button {
                        sendCurrentPrompt()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(.cyan, in: Circle())
                    .disabled(isSending)
                    .accessibilityLabel("Send prompt")
                }

                holdToTalkControl
            }

            HStack(spacing: 5) {
                Image(systemName: isSending
                      ? "arrow.up.circle.fill"
                      : (isListening ? "waveform" : "mic.fill"))
                    .font(.caption2.weight(.bold))
                Text(isSending ? "Sending to \(destination.title)…" : vibeStatus)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if session.isConnected, session.activeAppName.isEmpty == false {
                    Text(session.activeAppName)
                        .lineLimit(1)
                }

                if session.telemetry.rttMilliseconds > 0 {
                    Text("\(session.telemetry.rttMilliseconds) ms")
                        .monospacedDigit()
                }
            }
            .font(.caption2.weight(.medium))
            .fontDesign(.rounded)
            .foregroundStyle(isListening ? .cyan : .white.opacity(0.55))
            .padding(.horizontal, 3)
            .accessibilityElement(children: .combine)
        }
    }

    private var clipboardMenu: some View {
        Menu {
            Button {
                appendClipboardToPrompt()
            } label: {
                Label("Paste into Prompt", systemImage: "doc.on.clipboard")
            }

            Button {
                sendClipboardToMac()
            } label: {
                Label("Type Clipboard on Mac", systemImage: "macbook.and.iphone")
            }
            .disabled(session.isConnected == false)
        } label: {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.mint)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Clipboard handoff")
    }

    private var holdToTalkControl: some View {
        let active = isMicPressed || isListening

        return ZStack {
            if isListening {
                listeningPulse
            }

            Circle()
                .fill(active ? Color.cyan : Color.white)
                .frame(width: 50, height: 50)
                .shadow(color: (active ? Color.cyan : Color.white).opacity(0.28), radius: active ? 8 : 4)

            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .scaleEffect(isMicPressed ? 0.93 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isMicPressed)
        .opacity(isSending ? 0.45 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHoldToTalkIfNeeded() }
                .onEnded { _ in endHoldToTalk() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Hold to talk")
        .accessibilityValue(isSending ? "Sending" : (isListening ? "Listening" : "Ready"))
        .accessibilityHint("Press and hold to dictate, then release to send. With VoiceOver, activate once to start and again to send.")
        .accessibilityAction {
            if isListening || isMicPressed {
                endHoldToTalk()
            } else {
                beginHoldToTalkIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var listeningPulse: some View {
        if reduceMotion {
            Circle()
                .stroke(Color.cyan.opacity(0.45), lineWidth: 2)
                .frame(width: 56, height: 56)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = (time.truncatingRemainder(dividingBy: 1.1)) / 1.1
                Circle()
                    .stroke(Color.cyan.opacity((1 - phase) * 0.45), lineWidth: 1.5)
                    .frame(width: 56, height: 56)
                    .scaleEffect(1 + phase * 0.35)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Trackpad

    private var compactTrackpad: some View {
        ZStack(alignment: .topTrailing) {
            PolishedTrackpadSurface(showDiagnostics: false)
                .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            Text("2-finger scroll  •  3-finger Spaces")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Voice actions

    private func beginHoldToTalkIfNeeded() {
        guard isSending == false, isMicPressed == false else { return }

        isMicPressed = true
        vibeStatus = "Starting microphone…"
        Haptics.touchTap()

        recognizer.requestAccess { granted in
            Task { @MainActor in
                guard isMicPressed else { return }

                guard granted else {
                    isMicPressed = false
                    vibeStatus = "Enable Mic & Speech in Settings"
                    Haptics.error()
                    return
                }

                promptText = ""

                do {
                    try recognizer.start { text, _ in
                        Task { @MainActor in
                            guard isMicPressed || isListening else { return }
                            promptText = text
                        }
                    }

                    guard isMicPressed else {
                        recognizer.stop()
                        return
                    }

                    isListening = true
                    vibeStatus = "Listening — release to send"
                    Haptics.gesture()
                } catch {
                    isMicPressed = false
                    isListening = false
                    vibeStatus = error.localizedDescription
                    Haptics.error()
                }
            }
        }
    }

    private func endHoldToTalk() {
        guard isMicPressed || isListening else { return }

        isMicPressed = false

        guard isListening else {
            vibeStatus = "Hold mic, release to send"
            return
        }

        recognizer.stop()
        isListening = false
        Haptics.touchTap()

        let clean = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false else {
            vibeStatus = "No voice heard — hold to try again"
            return
        }

        sendCurrentPrompt()
    }

    private func usePrompt(_ prompt: String) {
        recognizer.stop()
        isMicPressed = false
        isListening = false
        promptText = prompt
        vibeStatus = "Prompt ready — edit or send"
        Haptics.touchTap()
    }

    private func appendClipboardToPrompt() {
        guard let clipboard = boundedClipboardText() else {
            vibeStatus = "Clipboard has no text"
            Haptics.error()
            return
        }

        recognizer.stop()
        isMicPressed = false
        isListening = false
        if promptText.isEmpty {
            promptText = clipboard
        } else {
            promptText += promptText.hasSuffix("\n") ? clipboard : "\n\(clipboard)"
        }
        vibeStatus = "Clipboard added"
        Haptics.touchTap()
    }

    private func sendClipboardToMac() {
        guard session.isConnected else {
            vibeStatus = "Connect to Mac first"
            Haptics.error()
            return
        }
        guard let clipboard = boundedClipboardText() else {
            vibeStatus = "Clipboard has no text"
            Haptics.error()
            return
        }

        session.send(.typeText(clipboard))
        session.flashAction("Clipboard\nSent to Mac", success: true)
        vibeStatus = "Clipboard typed on Mac"
        Haptics.gesture()
    }

    private func boundedClipboardText() -> String? {
        guard let raw = UIPasteboard.general.string, raw.isEmpty == false else { return nil }
        return String(raw.prefix(8_000))
    }

    private func sendCurrentPrompt() {
        let clean = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false, isSending == false else { return }

        guard session.isConnected else {
            vibeStatus = "Connect to Mac first"
            Haptics.error()
            return
        }

        recognizer.stop()
        isMicPressed = false
        isListening = false
        isSending = true
        vibeStatus = "Sending to \(destination.title)…"

        let targetDestination = destination
        let targetProject = selectedProject
        lastPrompt = clean

        Task { @MainActor in
            await VoiceAgentRouter.route(
                prompt: clean,
                destination: targetDestination,
                project: targetProject,
                session: session
            ) { newStatus in
                vibeStatus = newStatus
            }

            promptText = ""
            isSending = false
            try? await Task.sleep(nanoseconds: 900_000_000)
            vibeStatus = "Hold mic, release to send"
        }
    }
}

private struct CompactVibePreset: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let prompt: String

    static let defaults: [CompactVibePreset] = [
        CompactVibePreset(
            id: "fix",
            title: "Fix error",
            symbol: "wrench.and.screwdriver.fill",
            prompt: "Inspect the current error or failing behavior, find the root cause, implement the fix, run the relevant tests/build, and keep going until it passes."
        ),
        CompactVibePreset(
            id: "continue",
            title: "Continue",
            symbol: "forward.fill",
            prompt: "Continue implementing the current task from the existing project state. Inspect what is unfinished, choose the next logical step, implement it, and verify it."
        ),
        CompactVibePreset(
            id: "test",
            title: "Test + fix",
            symbol: "checkmark.seal.fill",
            prompt: "Run the relevant tests, lint and build. Fix regressions or failures you find, then rerun verification until everything is green."
        ),
        CompactVibePreset(
            id: "polish",
            title: "Polish UI",
            symbol: "wand.and.sparkles",
            prompt: "Review the current UI. Improve hierarchy, spacing, responsiveness, accessibility and interaction polish without breaking functionality."
        ),
        CompactVibePreset(
            id: "ship",
            title: "Verify + ship",
            symbol: "paperplane.fill",
            prompt: "Review the current changes, run the relevant verification, fix issues, then commit and push the verified work with a clear commit message."
        )
    ]
}
