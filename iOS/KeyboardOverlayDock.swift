import SwiftUI

/// Compact Mac keyboard dock. Does not leave the current remote mode.
struct KeyboardOverlayDock: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Type to Mac…", text: $text)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit { sendText() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Text to the Mac")

                    Button("Send") { sendText() }
                        .font(KamihiUI.bodyFont)
                        .foregroundStyle(.white)
                        .frame(minWidth: 64, minHeight: KamihiUI.controlHeight)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .accessibilityLabel("Send text")

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
                    key("esc", code: 53)
                    key("tab", code: 48)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            focused = true
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
            let f = flags()
            session.send(.keyDown(code: code, flags: f))
            session.send(.keyUp(code: code, flags: f))
            Haptics.click()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: KamihiUI.controlHeight)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
    }

    private func flags() -> UInt64 {
        var value: UInt64 = 0
        if command { value |= 1 << 20 }
        if shift { value |= 1 << 17 }
        if option { value |= 1 << 19 }
        if control { value |= 1 << 18 }
        return value
    }

    private func sendText() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        session.send(.typeText(value))
        text = ""
        Haptics.click()
    }
}
