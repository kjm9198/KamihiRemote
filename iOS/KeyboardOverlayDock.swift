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

/// Dictate a prompt on iPhone, then type + Return on the Mac (Cursor / ChatGPT agents).
struct DictatePromptSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @State private var transcript = ""
    @State private var isListening = false
    @State private var status = "Tap the mic, speak your prompt, then Send."
    @State private var recognizer = PromptSpeechRecognizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(status)
                    .font(KamihiUI.captionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $transcript)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button {
                        toggleListen()
                    } label: {
                        Label(isListening ? "Stop" : "Mic", systemImage: isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        sendPrompt()
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Dictate Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        recognizer.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear { recognizer.stop() }
        }
    }

    private func toggleListen() {
        if isListening {
            recognizer.stop()
            isListening = false
            status = "Review the text, then Send."
            return
        }
        recognizer.requestAccess { ok in
            guard ok else {
                status = "Enable Speech Recognition + Microphone in Settings."
                return
            }
            do {
                try recognizer.start { text in
                    transcript = text
                }
                isListening = true
                status = "Listening…"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func sendPrompt() {
        let value = transcript
        guard value.isEmpty == false else { return }
        recognizer.stop()
        isListening = false
        // Type prompt character-by-character so spaces survive, then Return to send.
        for character in value {
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
        session.send(.keyDown(code: 36, flags: 0))
        session.send(.keyUp(code: 36, flags: 0))
        session.flashAction("Prompt sent", success: true)
        dismiss()
    }
}

final class PromptSpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    private let speech = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioApplication.requestRecordPermission { mic in
                DispatchQueue.main.async {
                    completion(status == .authorized && mic)
                }
            }
        }
    }

    func start(onUpdate: @escaping (String) -> Void) throws {
        stop()
        guard let speech, speech.isAvailable else {
            throw NSError(domain: "KamihiSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition unavailable"])
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        task = speech.recognitionTask(with: request) { result, _ in
            guard let result else { return }
            DispatchQueue.main.async {
                onUpdate(result.bestTranscription.formattedString)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
