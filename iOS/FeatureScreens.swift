import SwiftUI

struct PresentationScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        VStack(spacing: 16) {
            Text("PRESENTATION")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 12) {
                bigButton("Previous", "chevron.left") { send(.previous) }
                bigButton("Next", "chevron.right") { send(.next) }
            }
            HStack(spacing: 12) {
                smallButton("Start", "play.fill") { send(.start) }
                smallButton("Black", "rectangle.fill") { send(.black) }
                smallButton("End", "xmark") { send(.end) }
            }
            Picker("Profile", selection: $session.preferences.presentationProfile) {
                ForEach(PresentationProfile.allCases) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding(20)
    }

    private func send(_ action: PresentationAction) {
        session.send(.presentation(action))
        Haptics.slideChange()
    }

    private func bigButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 28, weight: .semibold))
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .accessibilityLabel(title)
    }

    private func smallButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

struct KeyboardScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var text = ""
    @State private var command = false
    @State private var option = false
    @State private var control = false
    @State private var shift = false

    var body: some View {
        VStack(spacing: 14) {
            Text("KEYBOARD")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            TextField("Type to the Mac", text: $text)
                .textFieldStyle(.plain)
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .foregroundStyle(.white)
                .onSubmit { sendText() }
                .submitLabel(.send)
            HStack {
                modifier("⌘", $command)
                modifier("⌥", $option)
                modifier("⌃", $control)
                modifier("⇧", $shift)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(["esc", "tab", "return", "space", "left", "right", "up", "down"], id: \.self) { key in
                    Button(key) { tap(key) }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func modifier(_ title: String, _ value: Binding<Bool>) -> some View {
        Button(title) { value.wrappedValue.toggle() }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(value.wrappedValue ? .black : .white)
            .background(value.wrappedValue ? Color.white : Color.clear, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func flags() -> UInt64 {
        var value: UInt64 = 0
        if command { value |= 1 << 20 }
        if shift { value |= 1 << 17 }
        if option { value |= 1 << 19 }
        if control { value |= 1 << 18 }
        return value
    }

    private func tap(_ name: String) {
        let code: UInt16
        switch name {
        case "esc": code = 53
        case "tab": code = 48
        case "return": code = 36
        case "space": code = 49
        case "left": code = 123
        case "right": code = 124
        case "up": code = 126
        default: code = 125
        }
        session.send(.keyDown(code: code, flags: flags()))
        session.send(.keyUp(code: code, flags: flags()))
        Haptics.click()
    }

    private func sendText() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        session.send(.typeText(value))
        text = ""
    }
}

struct MediaScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        VStack(spacing: 18) {
            Text("MEDIA")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 16) {
                media("backward.end.fill") { session.send(.media(.previous)) }
                media("playpause.fill", size: 36) { session.send(.media(.playPause)) }
                media("forward.end.fill") { session.send(.media(.next)) }
            }
            HStack(spacing: 12) {
                media("speaker.minus.fill") { session.send(.media(.volumeDown)) }
                media("speaker.slash.fill") { session.send(.media(.mute)) }
                media("speaker.plus.fill") { session.send(.media(.volumeUp)) }
            }
            Spacer()
        }
        .padding(20)
    }

    private func media(_ symbol: String, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .accessibilityLabel(symbol)
    }
}

struct DeckScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 12) {
            Text("DECK")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: horizontalSizeClass == .regular ? 4 : 3), spacing: 10) {
                ForEach(session.deck) { button in
                    Button {
                        run(button)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: button.symbol).font(.system(size: 20, weight: .semibold))
                            Text(button.title).font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    .accessibilityLabel(button.title)
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func run(_ button: DeckButton) {
        switch button.kind {
        case .shortcut:
            session.send(.typeText(button.payload))
        case .openApp:
            session.send(.system(.launchpad))
        case .openURL:
            session.send(.typeText(button.payload))
        case .system:
            if let action = SystemAction(rawValue: button.payload) {
                session.send(.system(action))
            }
        case .presentation:
            if let action = PresentationAction(rawValue: button.payload) {
                session.send(.presentation(action))
            }
        case .media:
            if let action = MediaAction(rawValue: button.payload) {
                session.send(.media(action))
            }
        }
        Haptics.gesture()
    }
}
