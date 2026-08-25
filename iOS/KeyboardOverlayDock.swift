import SwiftUI
import Speech
import AVFoundation

/// Compact Mac keyboard dock with live focused-text mirroring when Accessibility exposes it.
struct KeyboardOverlayDock: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var baseline = ""
    @State private var applyingRemote = false
    @State private var userIsEditing = false
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false
    @State private var statusLine = "Live text unavailable here"
    @State private var didApplySnapshot = false

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 10) {
                HStack {
                    Text(statusLine)
                        .font(KamihiUI.captionFont)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Button("Refresh") {
                        didApplySnapshot = false
                        userIsEditing = false
                        session.requestFocusedText()
                    }
                    .font(KamihiUI.captionFont)
                    .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 8) {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.return)
                        .onSubmit { pressReturn() }
                        .onChange(of: text) { _, newValue in
                            handleEdit(newValue)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Text to the Mac")

                    Button("Done") { dismiss() }
                        .font(KamihiUI.bodyFont)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(minWidth: 56, minHeight: KamihiUI.controlHeight)
                        .accessibilityLabel("Dismiss keyboard")
                }

                HStack(spacing: 8) {
                    modifier("⌘", $command)
                    modifier("⌥", $option)
                    modifier("⌃", $control)
                    modifier("⇧", $shift)
                    key("space", code: 49)
                    key("⌫", code: 51)
                    key("esc", code: 53)
                    key("tab", code: 48)
                    key("return", code: 36)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            focused = true
            didApplySnapshot = false
            userIsEditing = false
            session.requestFocusedText()
        }
        .onChange(of: session.focusedTextStatus) { _, _ in
            applyFocusedSnapshotIfNeeded()
        }
        .onChange(of: session.focusedTextValue) { _, _ in
            applyFocusedSnapshotIfNeeded()
        }
    }

    private var placeholder: String {
        switch session.focusedTextStatus {
        case .value: return "Edit Mac text"
        case .secure: return "Secure field — typing only"
        case .unavailable: return "Type to Mac…"
        }
    }

    private func applyFocusedSnapshotIfNeeded() {
        // Never overwrite while the user is typing — that was deleting spaces.
        guard userIsEditing == false, didApplySnapshot == false else { return }
        applyingRemote = true
        defer { applyingRemote = false }
        switch session.focusedTextStatus {
        case .value:
            text = session.focusedTextValue
            baseline = session.focusedTextValue
            statusLine = "Editing Mac text"
            didApplySnapshot = true
        case .secure:
            text = ""
            baseline = ""
            statusLine = "Password field — live text hidden"
            didApplySnapshot = true
        case .unavailable:
            statusLine = session.focusedTextValue.isEmpty ? "Live text unavailable here" : session.focusedTextValue
            didApplySnapshot = true
        }
    }

    private func dismiss() {
        focused = false
        session.showsKeyboard = false
    }

    private func modifier(_ title: String, _ value: Binding<Bool>) -> some View {
        Button(title) { value.wrappedValue.toggle() }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: KamihiUI.controlHeight)
            .foregroundStyle(value.wrappedValue ? .black : .white)
            .background(value.wrappedValue ? Color.white : Color.clear, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(title)
            .accessibilityAddTraits(value.wrappedValue ? .isSelected : [])
    }

    private func key(_ title: String, code: UInt16) -> some View {
        Button(title) {
            press(code: code)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: KamihiUI.controlHeight)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
    }

    private func press(code: UInt16) {
        userIsEditing = true
        let f = flags()
        session.send(.keyDown(code: code, flags: f))
        session.send(.keyUp(code: code, flags: f))
        Haptics.click()
        applyingRemote = true
        if code == 51, text.isEmpty == false {
            text.removeLast()
        } else if code == 49 {
            text.append(" ")
        }
        baseline = text
        applyingRemote = false
    }

    private func pressReturn() {
        press(code: 36)
    }

    private func flags() -> UInt64 {
        var value: UInt64 = 0
        if command { value |= 1 << 20 }
        if shift { value |= 1 << 17 }
        if option { value |= 1 << 19 }
        if control { value |= 1 << 18 }
        return value
    }

    private func handleEdit(_ newValue: String) {
        guard applyingRemote == false else { return }
        userIsEditing = true
        if newValue == baseline { return }

        // Prefer real space key events so Mac text fields accept spaces reliably.
        if newValue.hasPrefix(baseline) {
            let suffix = String(newValue.dropFirst(baseline.count))
            for character in suffix {
                if character == " " {
                    session.send(.keyDown(code: 49, flags: 0))
                    session.send(.keyUp(code: 49, flags: 0))
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

        // Diverged edit: delete old, type new (preserve spaces via key events).
        for _ in 0..<baseline.count {
            session.send(.keyDown(code: 51, flags: 0))
            session.send(.keyUp(code: 51, flags: 0))
        }
        for character in newValue {
            if character == " " {
                session.send(.keyDown(code: 49, flags: 0))
                session.send(.keyUp(code: 49, flags: 0))
            } else {
                session.send(.typeText(String(character)))
            }
        }
        baseline = newValue
    }
}

/// Two-tap voice command surface: select a project + agent once, then tap, speak, tap to send.
struct DictatePromptSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    @AppStorage("voiceAgentDestination") private var destinationRaw = VoiceAgentDestination.antigravity.rawValue
    @AppStorage("voiceAgentProjectID") private var selectedProjectID = "kamihi-remote"
    @AppStorage("voiceAgentAutoSend") private var autoSend = true

    @State private var transcript = ""
    @State private var isListening = false
    @State private var isSending = false
    @State private var status = "Choose a project, then tap the mic."
    @State private var recognizer = PromptSpeechRecognizer()
    @State private var projects: [VoiceProject] = VoiceProjectStore.load()
    @State private var showsProjects = false

    private var destination: VoiceAgentDestination {
        VoiceAgentDestination(rawValue: destinationRaw) ?? .antigravity
    }

    private var selectedProject: VoiceProject? {
        guard selectedProjectID.isEmpty == false else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.02, green: 0.08, blue: 0.10), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        projectSelector
                        destinationSelector
                        microphoneArea
                        transcriptCard
                        sendControls
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Voice Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        recognizer.stop()
                        dismiss()
                    }
                    .disabled(isSending)
                }
            }
            .sheet(isPresented: $showsProjects) {
                VoiceProjectManagerSheet(projects: $projects, selectedProjectID: $selectedProjectID)
            }
            .onAppear {
                session.send(.requestAppList)
                if selectedProjectID.isEmpty == false,
                   projects.contains(where: { $0.id == selectedProjectID }) == false {
                    selectedProjectID = projects.first?.id ?? ""
                }
            }
            .onDisappear { recognizer.stop() }
        }
        .preferredColorScheme(.dark)
    }

    private var projectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PROJECT")

            Button {
                showsProjects = true
                Haptics.touchTap()
            } label: {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.16))
                            .frame(width: 42, height: 42)
                        Image(systemName: selectedProject == nil ? "macwindow" : "folder.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedProject?.name ?? "Current app only")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(selectedProject?.path ?? "Do not switch project folders")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            .accessibilityLabel("Selected project \(selectedProject?.name ?? "current app only")")
        }
    }

    private var destinationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("SEND TO")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(VoiceAgentDestination.allCases) { item in
                    let selected = item == destination
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            destinationRaw = item.rawValue
                        }
                        Haptics.touchTap()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(selected ? .cyan : .white.opacity(0.78))
                        .padding(.horizontal, 13)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(selected ? Color.cyan.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selected ? Color.cyan.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .accessibilityLabel("Send to \(item.title)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var microphoneArea: some View {
        VStack(spacing: 12) {
            ZStack {
                if isListening {
                    VoicePulseRings()
                        .frame(width: 178, height: 178)
                        .transition(.opacity)
                }

                Button {
                    microphoneTapped()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.cyan : Color.white)
                            .frame(width: 104, height: 104)
                            .shadow(color: (isListening ? Color.cyan : Color.white).opacity(0.22), radius: 28, y: 8)

                        Image(systemName: isListening ? "arrow.up.circle.fill" : "mic.fill")
                            .font(.system(size: isListening ? 42 : 36, weight: .semibold))
                            .foregroundStyle(.black)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isListening ? 1.03 : 1)
                .animation(.snappy(duration: 0.24), value: isListening)
                .disabled(isSending)
                .accessibilityLabel(isListening ? "Stop recording and send" : "Start recording")
            }
            .frame(height: 178)

            Text(isSending ? "Sending…" : (isListening ? "Tap again to send" : "Tap to speak"))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.opacity)

            Text(status)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
                .animation(.easeInOut(duration: 0.2), value: status)
        }
        .padding(.vertical, 4)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionLabel("TRANSCRIPT")
                Spacer()
                if transcript.isEmpty == false, isListening == false, isSending == false {
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            transcript = ""
                        }
                        Haptics.click()
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                }
            }

            ZStack(alignment: .topLeading) {
                if transcript.isEmpty {
                    Text(isListening ? "Listening…" : "Your dictated prompt appears here. You can edit it before sending.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.28))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $transcript)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(minHeight: 116, maxHeight: 170)
                    .padding(.horizontal, 1)
                    .background(Color.clear)
                    .disabled(isSending)
            }
            .padding(11)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var sendControls: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $autoSend) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send when I stop")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Two taps: start recording, then send")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .tint(.cyan)
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 2)

            if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
               isListening == false {
                Button {
                    sendPrompt()
                } label: {
                    HStack(spacing: 9) {
                        if isSending {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending…" : "Send to \(destination.title)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.26), value: transcript.isEmpty)
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.38))
    }

    private func microphoneTapped() {
        guard isSending == false else { return }
        if isListening {
            stopListening(send: autoSend)
        } else {
            startListening()
        }
    }

    private func startListening() {
        recognizer.requestAccess { ok in
            guard ok else {
                status = "Enable Speech Recognition + Microphone in Settings."
                Haptics.rightClick()
                return
            }

            transcript = ""
            do {
                try recognizer.start { text, _ in
                    transcript = text
                }
                withAnimation(.snappy(duration: 0.25)) {
                    isListening = true
                }
                status = "Listening for your instruction…"
                Haptics.gesture()
            } catch {
                status = error.localizedDescription
                Haptics.rightClick()
            }
        }
    }

    private func stopListening(send: Bool) {
        recognizer.stop()
        withAnimation(.snappy(duration: 0.25)) {
            isListening = false
        }
        Haptics.touchTap()

        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false else {
            status = "I didn't catch anything. Tap the mic and try again."
            return
        }

        if send {
            sendPrompt()
        } else {
            status = "Review the transcript, then tap Send."
        }
    }

    private func sendPrompt() {
        let value = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, isSending == false else { return }
        guard session.isConnected else {
            status = "Connect Kamihi Remote to your Mac first."
            Haptics.rightClick()
            return
        }

        recognizer.stop()
        isListening = false
        isSending = true
        status = "Preparing \(destination.title)…"

        let target = destination
        let project = selectedProject
        Task { @MainActor in
            await VoiceAgentRouter.route(
                prompt: value,
                destination: target,
                project: project,
                session: session
            ) { newStatus in
                status = newStatus
            }

            transcript = ""
            isSending = false
            try? await Task.sleep(nanoseconds: 420_000_000)
            dismiss()
        }
    }
}

private struct VoicePulseRings: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let raw = (time / 1.45) + (Double(index) / 3.0)
                    let phase = raw - floor(raw)
                    Circle()
                        .stroke(Color.cyan.opacity((1 - phase) * 0.34), lineWidth: 1.2)
                        .scaleEffect(0.58 + (phase * 0.48))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

final class PromptSpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    private var speech: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    override init() {
        super.init()
        let locale = SFSpeechRecognizer.supportedLocales().contains(Locale.current) ? Locale.current : Locale(identifier: "en-US")
        speech = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speech?.delegate = self
    }

    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioSession.sharedInstance().requestRecordPermission { mic in
                DispatchQueue.main.async {
                    completion(status == .authorized && mic)
                }
            }
        }
    }

    func start(onUpdate: @escaping (String, Bool) -> Void) throws {
        stop()
        guard let speech, speech.isAvailable else {
            throw NSError(domain: "KamihiSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition unavailable"])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw NSError(domain: "KamihiSpeech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone hardware unavailable"])
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = speech.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async {
                    onUpdate(result.bestTranscription.formattedString, result.isFinal)
                }
            }
            if let error {
                NSLog("Kamihi speech recognition error: %@", error.localizedDescription)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }
            audioEngine = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
