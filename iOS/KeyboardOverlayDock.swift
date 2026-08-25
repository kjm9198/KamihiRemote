import SwiftUI

/// Compact Mac keyboard dock with live focused-text mirroring when Accessibility exposes it.
struct KeyboardOverlayDock: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var baseline = ""
    @State private var applyingRemote = false
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false
    @State private var statusLine = "Live text unavailable here"

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 10) {
                Text(statusLine)
                    .font(KamihiUI.captionFont)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($focused)
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
            session.requestFocusedText()
        }
        .onChange(of: session.focusedTextStatus) { _, _ in
            applyFocusedSnapshot()
        }
        .onChange(of: session.focusedTextValue) { _, _ in
            applyFocusedSnapshot()
        }
    }

    private var placeholder: String {
        switch session.focusedTextStatus {
        case .value: return "Edit Mac text"
        case .secure: return "Secure field — typing only"
        case .unavailable: return "Type to Mac…"
        }
    }

    private func applyFocusedSnapshot() {
        applyingRemote = true
        defer { applyingRemote = false }
        switch session.focusedTextStatus {
        case .value:
            text = session.focusedTextValue
            baseline = session.focusedTextValue
            statusLine = "Editing Mac text"
        case .secure:
            text = ""
            baseline = ""
            statusLine = "Password field — live text hidden"
        case .unavailable:
            statusLine = session.focusedTextValue.isEmpty ? "Live text unavailable here" : session.focusedTextValue
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
        let f = flags()
        session.send(.keyDown(code: code, flags: f))
        session.send(.keyUp(code: code, flags: f))
        Haptics.click()
        if code == 51, text.isEmpty == false {
            applyingRemote = true
            text.removeLast()
            baseline = text
            applyingRemote = false
        }
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
        if newValue == baseline { return }
        if baseline.hasPrefix(newValue), baseline.count > newValue.count {
            let deletes = baseline.count - newValue.count
            for _ in 0..<deletes {
                session.send(.keyDown(code: 51, flags: 0))
                session.send(.keyUp(code: 51, flags: 0))
            }
            baseline = newValue
            return
        }
        if newValue.hasPrefix(baseline) {
            let suffix = String(newValue.dropFirst(baseline.count))
            if suffix.isEmpty == false {
                session.send(.typeText(suffix))
            }
            baseline = newValue
            return
        }
        // Replace: delete old length then type new.
        for _ in 0..<baseline.count {
            session.send(.keyDown(code: 51, flags: 0))
            session.send(.keyUp(code: 51, flags: 0))
        }
        if newValue.isEmpty == false {
            session.send(.typeText(newValue))
        }
        baseline = newValue
    }
}
