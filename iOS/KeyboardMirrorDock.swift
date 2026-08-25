import SwiftUI

/// Keyboard overlay that mirrors the focused Mac text field when macOS Accessibility
/// exposes its value. Even when mirroring is unavailable, typing and Backspace still
/// operate on the focused Mac control through real keyboard events.
struct KeyboardMirrorDock: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var focused: Bool

    @State private var text = ""
    @State private var lastSyncedText = ""
    @State private var applyingSnapshot = false
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Focused Mac text", text: $text, axis: .vertical)
                            .textFieldStyle(.plain)
                            .focused($focused)
                            .lineLimit(1...4)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                            .foregroundStyle(.white)
                            .accessibilityLabel("Focused text on the Mac")
                            .onChange(of: text) { _, newValue in
                                syncLocalChange(newValue)
                            }

                        Text(session.keyboardDesktopTextEditable
                             ? "Mirroring the focused Mac text field"
                             : "Live text unavailable here — typing and Delete still work")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Button {
                        session.requestKeyboardSnapshot()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Refresh focused Mac text")

                    Button("Done") { dismiss() }
                        .font(KamihiUI.bodyFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(minWidth: 54, minHeight: 42)
                        .accessibilityLabel("Dismiss keyboard")
                }

                HStack(spacing: 7) {
                    modifier("⌘", $command)
                    modifier("⌥", $option)
                    modifier("⌃", $control)
                    modifier("⇧", $shift)
                    key("esc", code: 53)
                    key("tab", code: 48)
                    key("⌫", code: 51, updateLocalDelete: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            focused = true
            session.requestKeyboardSnapshot()
        }
        .onChange(of: session.keyboardSnapshotRevision) { _, _ in
            applyingSnapshot = true
            text = session.keyboardDesktopText
            lastSyncedText = session.keyboardDesktopText
            DispatchQueue.main.async {
                applyingSnapshot = false
            }
        }
    }

    private func dismiss() {
        focused = false
        session.showsKeyboard = false
    }

    private func modifier(_ title: String, _ value: Binding<Bool>) -> some View {
        Button(title) { value.wrappedValue.toggle() }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(value.wrappedValue ? .black : .white)
            .background(value.wrappedValue ? Color.white : Color.clear, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(title)
            .accessibilityAddTraits(value.wrappedValue ? .isSelected : [])
    }

    private func key(_ title: String, code: UInt16, updateLocalDelete: Bool = false) -> some View {
        Button(title) {
            if updateLocalDelete, text.isEmpty == false {
                applyingSnapshot = true
                text.removeLast()
                lastSyncedText = text
                DispatchQueue.main.async { applyingSnapshot = false }
            }
            sendKey(code)
            if updateLocalDelete {
                session.requestKeyboardSnapshot(after: 0.12)
            }
            Haptics.click()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 40)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title == "⌫" ? "Delete backward" : title)
    }

    private func sendKey(_ code: UInt16) {
        let f = flags()
        session.send(.keyDown(code: code, flags: f))
        session.send(.keyUp(code: code, flags: f))
    }

    private func flags() -> UInt64 {
        var value: UInt64 = 0
        if command { value |= 1 << 20 }
        if shift { value |= 1 << 17 }
        if option { value |= 1 << 19 }
        if control { value |= 1 << 18 }
        return value
    }

    private func syncLocalChange(_ newValue: String) {
        guard applyingSnapshot == false else { return }
        let oldValue = lastSyncedText
        guard newValue != oldValue else { return }

        if newValue.hasPrefix(oldValue) {
            let suffix = String(newValue.dropFirst(oldValue.count))
            if suffix.isEmpty == false {
                session.send(.typeText(suffix))
            }
        } else if oldValue.hasPrefix(newValue) {
            let removed = max(0, oldValue.count - newValue.count)
            for _ in 0..<min(removed, 250) {
                session.send(.keyDown(code: 51, flags: 0))
                session.send(.keyUp(code: 51, flags: 0))
            }
        } else {
            // Arbitrary mid-string edit: make the Mac field match the mirrored iPhone
            // field by Select All + replacement. This is deterministic and supports
            // deletion/replacement, rather than only appending text.
            session.send(.keyDown(code: 0, flags: 1 << 20)) // Command-A
            session.send(.keyUp(code: 0, flags: 1 << 20))
            if newValue.isEmpty == false {
                session.send(.typeText(newValue))
            } else {
                session.send(.keyDown(code: 51, flags: 0))
                session.send(.keyUp(code: 51, flags: 0))
            }
        }

        lastSyncedText = newValue
    }
}
