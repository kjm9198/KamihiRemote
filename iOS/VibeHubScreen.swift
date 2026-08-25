import SwiftUI

/// Vibe Mode Mission Control — voice + text routing, project switching, reusable prompts and integrated trackpad.
struct VibeHubScreen: View {
    @EnvironmentObject private var session: RemoteSession

    @AppStorage("voiceAgentDestination") private var destinationRaw = VoiceAgentDestination.antigravity.rawValue
    @AppStorage("voiceAgentProjectID") private var selectedProjectID = "kamihi-remote"
    @AppStorage("voiceAgentAutoSend") private var autoSend = true

    @State private var projects: [VoiceProject] = VoiceProjectStore.load()
    @State private var showsProjectManager = false
    @State private var promptText = ""
    @State private var isListening = false
    @State private var isSending = false
    @State private var vibeStatus = "Tap the mic to vibe code"
    @State private var recognizer = PromptSpeechRecognizer()
    @State private var recentPrompts: [VibePromptHistoryEntry] = VibePromptHistoryStore.load()

    @State private var isDevServerRunning = true

    private var destination: VoiceAgentDestination {
        VoiceAgentDestination(rawValue: destinationRaw) ?? .antigravity
    }

    private var selectedProject: VoiceProject? {
        projects.first(where: { $0.id == selectedProjectID }) ?? projects.first
    }

    var body: some View {
        GeometryReader { geo in
            let trackpadHeight = max(170, geo.size.height * 0.42)
            let topHeight = max(240, geo.size.height - trackpadHeight - 10)

            VStack(spacing: 6) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        heroStatusRow
                        projectSelectorBar
                        centerMicrophoneSection
                        promptInputBar
                        promptShelf
                        destinationPills
                    }
                    .padding(.horizontal, KamihiUI.pad)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
                .frame(height: topHeight)

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
        .sheet(isPresented: $showsProjectManager) {
            VoiceProjectManagerSheet(projects: $projects, selectedProjectID: $selectedProjectID)
        }
        .onAppear {
            projects = VoiceProjectStore.load()
            recentPrompts = VibePromptHistoryStore.load()
            if selectedProjectID.isEmpty || !projects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = projects.first?.id ?? "kamihi-remote"
            }
        }
        .onDisappear {
            recognizer.stop()
        }
    }

    // MARK: - Status + Project

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
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private var projectSelectorBar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(projects) { project in
                    Button {
                        selectedProjectID = project.id
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
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text(selectedProject?.name ?? "Select Project")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            Spacer()

            Button {
                session.sendAcknowledged(.openURL("http://localhost:3000"), title: "Preview")
                Haptics.touchTap()
            } label: {
                Label("Preview", systemImage: "globe")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    // MARK: - Voice + Prompt Composer

    private var centerMicrophoneSection: some View {
        VStack(spacing: 6) {
            ZStack {
                if isListening {
                    TimelineView(.animation) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                let raw = (time / 1.4) + (Double(index) / 3.0)
                                let phase = raw - floor(raw)
                                Circle()
                                    .stroke(Color.cyan.opacity((1 - phase) * 0.4), lineWidth: 1.5)
                                    .scaleEffect(0.6 + (phase * 0.5))
                            }
                        }
                    }
                    .frame(width: 110, height: 110)
                    .allowsHitTesting(false)
                }

                Button {
                    handleMicrophoneTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isListening
                                        ? [Color.cyan, Color.blue]
                                        : [Color.white, Color(white: 0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: (isListening ? Color.cyan : Color.white).opacity(0.35), radius: 14, y: 4)

                        Image(systemName: isListening ? "waveform" : "mic.fill")
                            .font(.system(size: isListening ? 26 : 24, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isListening ? 1.05 : 1.0)
                .animation(.snappy(duration: 0.2), value: isListening)
                .disabled(isSending)
            }
            .frame(height: 74)

            Text(isSending ? "Routing to \(destination.title)…" : (isListening ? "Listening… tap to send" : vibeStatus))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isListening ? .cyan : .white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    private var promptInputBar: some View {
        HStack(spacing: 6) {
            TextField("Prompt to \(destination.title)…", text: $promptText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(.white)
                .submitLabel(.send)
                .onSubmit {
                    sendCurrentPrompt()
                }

            if !promptText.isEmpty {
                Button {
                    sendCurrentPrompt()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .accessibilityLabel("Send prompt")
            }
        }
    }

    /// Reusable coding intents + locally persisted prompt history.
    private var promptShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(VibePromptPreset.defaults) { preset in
                    Button {
                        usePrompt(preset.prompt)
                    } label: {
                        Label(preset.title, systemImage: preset.symbol)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.82))
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityLabel("Use \(preset.title) prompt")
                }

                if let last = recentPrompts.first {
                    Button {
                        usePrompt(last.prompt)
                    } label: {
                        Label("Repeat last", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityLabel("Reuse last prompt")
                }

                if recentPrompts.isEmpty == false {
                    Menu {
                        ForEach(recentPrompts.prefix(10)) { entry in
                            Button {
                                usePrompt(entry.prompt)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(entry.shortTitle)
                                    Text(entry.contextLabel)
                                }
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            VibePromptHistoryStore.clear()
                            recentPrompts = []
                            Haptics.touchTap()
                        } label: {
                            Label("Clear Prompt History", systemImage: "trash")
                        }
                    } label: {
                        Label("Recent", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                    }
                    .foregroundStyle(.white.opacity(0.72))
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var destinationPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(VoiceAgentDestination.allCases) { item in
                    let selected = item == destination
                    Button {
                        destinationRaw = item.rawValue
                        Haptics.touchTap()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 10, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(selected ? .cyan : .white.opacity(0.6))
                        .background(selected ? Color.cyan.opacity(0.16) : Color.clear, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Voice Actions

    private func handleMicrophoneTap() {
        guard !isSending else { return }
        if isListening {
            stopListeningAndSend()
        } else {
            startListening()
        }
    }

    private func startListening() {
        recognizer.requestAccess { granted in
            guard granted else {
                vibeStatus = "Enable Mic & Speech in Settings"
                Haptics.rightClick()
                return
            }

            promptText = ""
            do {
                try recognizer.start { text, isFinal in
                    promptText = text
                    if isFinal && autoSend {
                        stopListeningAndSend()
                    }
                }
                withAnimation(.snappy(duration: 0.2)) {
                    isListening = true
                }
                vibeStatus = "Listening…"
                Haptics.gesture()
            } catch {
                vibeStatus = error.localizedDescription
                Haptics.rightClick()
            }
        }
    }

    private func stopListeningAndSend() {
        recognizer.stop()
        withAnimation(.snappy(duration: 0.2)) {
            isListening = false
        }
        Haptics.touchTap()

        let clean = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            vibeStatus = "No voice heard. Tap to try again."
            return
        }

        sendCurrentPrompt()
    }

    private func usePrompt(_ prompt: String) {
        recognizer.stop()
        isListening = false
        promptText = prompt
        vibeStatus = "Prompt ready — edit or send"
        Haptics.touchTap()
    }

    private func sendCurrentPrompt() {
        let clean = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSending else { return }

        guard session.isConnected else {
            vibeStatus = "Connect to Mac first"
            Haptics.rightClick()
            return
        }

        recognizer.stop()
        isListening = false
        isSending = true
        vibeStatus = "Sending to \(destination.title)…"

        let targetDest = destination
        let targetProj = selectedProject

        Task { @MainActor in
            await VoiceAgentRouter.route(
                prompt: clean,
                destination: targetDest,
                project: targetProj,
                session: session
            ) { newStatus in
                vibeStatus = newStatus
            }

            VibePromptHistoryStore.record(
                prompt: clean,
                destination: targetDest,
                projectName: targetProj?.name
            )
            recentPrompts = VibePromptHistoryStore.load()
            promptText = ""
            isSending = false
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            vibeStatus = "Tap the mic to vibe code"
        }
    }
}

private struct VibePromptPreset: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let prompt: String

    static let defaults: [VibePromptPreset] = [
        VibePromptPreset(
            id: "fix",
            title: "Fix error",
            symbol: "wrench.and.screwdriver.fill",
            prompt: "Inspect the current error or failing behavior, find the root cause, implement the fix, run the relevant tests/build, and keep going until it passes."
        ),
        VibePromptPreset(
            id: "continue",
            title: "Continue",
            symbol: "forward.fill",
            prompt: "Continue implementing the current task from the existing project state. Inspect what is unfinished, choose the next logical step, implement it, and verify it."
        ),
        VibePromptPreset(
            id: "test",
            title: "Test + fix",
            symbol: "checkmark.seal.fill",
            prompt: "Run the relevant tests, lint and build. Fix every regression or failure you find, then rerun verification until everything is green."
        ),
        VibePromptPreset(
            id: "polish",
            title: "Polish UI",
            symbol: "wand.and.sparkles",
            prompt: "Review the current UI on mobile and desktop. Improve hierarchy, spacing, animations, accessibility and interaction polish without breaking functionality."
        ),
        VibePromptPreset(
            id: "ship",
            title: "Verify + ship",
            symbol: "paperplane.fill",
            prompt: "Review the current changes, run the relevant verification, fix any issues you find, then commit and push the verified work with a clear commit message."
        )
    ]
}

private struct VibePromptHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let prompt: String
    let destination: String
    let projectName: String?
    let createdAt: Date

    var shortTitle: String {
        let collapsed = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 54 else { return collapsed }
        return String(collapsed.prefix(51)) + "…"
    }

    var contextLabel: String {
        if let projectName, projectName.isEmpty == false {
            return "\(projectName) • \(destination)"
        }
        return destination
    }
}

private enum VibePromptHistoryStore {
    private static let key = "vibePromptHistoryV1"
    private static let limit = 20

    static func load() -> [VibePromptHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VibePromptHistoryEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    static func record(prompt: String, destination: VoiceAgentDestination, projectName: String?) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false else { return }

        var items = load()
        items.removeAll {
            $0.prompt == clean && $0.destination == destination.title && $0.projectName == projectName
        }
        items.insert(
            VibePromptHistoryEntry(
                id: UUID(),
                prompt: clean,
                destination: destination.title,
                projectName: projectName,
                createdAt: Date()
            ),
            at: 0
        )
        items = Array(items.prefix(limit))
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
