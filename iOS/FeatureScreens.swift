import SwiftUI

struct PresentationScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ModeShell {
            VStack(spacing: 12) {
                Text("PRESENTATION")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 10) {
                    bigButton("Previous", "chevron.left") { send(.previous) }
                    bigButton("Next", "chevron.right") { send(.next) }
                }
                HStack(spacing: 10) {
                    smallButton("Start", "play.fill") { send(.start) }
                    smallButton("Black", "rectangle.fill") { send(.black) }
                    smallButton("End", "xmark") { send(.end) }
                    smallButton("Laser", "circle.fill") {
                        session.pointerMode = session.pointerMode == .presentationLaser ? .macCursor : .presentationLaser
                        session.send(.laserVisible(session.pointerMode == .presentationLaser))
                        send(.pointer)
                    }
                }
                Picker("Profile", selection: $session.preferences.presentationProfile) {
                    ForEach(PresentationProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: session.preferences.presentationProfile) { _, _ in
                    session.preferences.save()
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func send(_ action: PresentationAction) {
        session.send(.presentation(action: action, profile: session.preferences.presentationProfile))
        Haptics.slideChange()
    }

    private func bigButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 24, weight: .semibold))
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .accessibilityLabel(title)
    }

    private func smallButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
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
        ModeShell(pointerRatio: 0.48, compactPointerHeight: 120) {
            VStack(spacing: 12) {
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
                    .accessibilityLabel("Text to the Mac")
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
                            .accessibilityLabel(key)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func modifier(_ title: String, _ value: Binding<Bool>) -> some View {
        Button(title) { value.wrappedValue.toggle() }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(value.wrappedValue ? .black : .white)
            .background(value.wrappedValue ? Color.white : Color.clear, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(title)
            .accessibilityAddTraits(value.wrappedValue ? .isSelected : [])
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
        ModeShell {
            VStack(spacing: 16) {
                Text("MEDIA")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 12) {
                    media("backward.end.fill", "Previous track") { session.send(.media(.previous)) }
                    media("playpause.fill", "Play pause", size: 32) { session.send(.media(.playPause)) }
                    media("forward.end.fill", "Next track") { session.send(.media(.next)) }
                }
                HStack(spacing: 12) {
                    media("speaker.minus.fill", "Volume down") { session.send(.media(.volumeDown)) }
                    media("speaker.slash.fill", "Mute") { session.send(.media(.mute)) }
                    media("speaker.plus.fill", "Volume up") { session.send(.media(.volumeUp)) }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func media(_ symbol: String, _ label: String, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .accessibilityLabel(label)
    }
}

struct DeckScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ModeShell(pointerRatio: 0.42, compactPointerHeight: 150) {
            VStack(spacing: 10) {
                HStack {
                    Text("DECK")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button("Edit") { session.showsDeckEditor = true }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityLabel("Edit deck")
                }
                GeometryReader { geo in
                    let columns = max(3, min(6, max(1, Int(geo.size.width / 92))))
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                            ForEach(session.deck) { button in
                                Button {
                                    run(button)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: button.symbol).font(.system(size: 20, weight: .semibold))
                                        Text(button.title)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .padding(6)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                                .accessibilityLabel(button.title)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding(12)
        }
        .sheet(isPresented: $session.showsDeckEditor) {
            DeckEditorSheet().environmentObject(session)
        }
    }

    private func run(_ button: DeckButton) {
        switch button.kind {
        case .shortcut:
            session.send(.shortcut(button.payload))
        case .openApp:
            session.send(.openApp(bundleID: button.payload))
        case .openURL:
            session.send(.openURL(button.payload))
        case .system:
            if let action = SystemAction(rawValue: button.payload) {
                session.send(.system(action))
            }
        case .presentation:
            if let action = PresentationAction(rawValue: button.payload) {
                session.send(.presentation(action: action, profile: session.preferences.presentationProfile))
            }
        case .media:
            if let action = MediaAction(rawValue: button.payload) {
                session.send(.media(action))
            }
        }
        Haptics.gesture()
    }
}

struct DeckEditorSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [DeckButton] = []
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($draft) { $button in
                    NavigationLink {
                        DeckTileEditor(button: $button, apps: session.hostApps)
                    } label: {
                        Label(button.title, systemImage: button.symbol)
                    }
                }
                .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { draft.remove(atOffsets: $0) }
                Button("Add tile") {
                    draft.append(DeckButton(id: UUID().uuidString, title: "New", symbol: "plus.app", kind: .openApp, payload: "com.apple.Safari"))
                }
            }
            .navigationTitle("Edit Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.deck = draft
                        DeckButton.save(draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .onAppear {
                draft = session.deck
                session.send(.requestAppList)
            }
        }
    }
}

struct DeckTileEditor: View {
    @Binding var button: DeckButton
    var apps: [HostAppEntry]
    @State private var urlText = ""

    var body: some View {
        Form {
            TextField("Name", text: $button.title)
            TextField("Symbol", text: $button.symbol)
            Picker("Kind", selection: $button.kind) {
                Text("Application").tag(DeckButton.Kind.openApp)
                Text("Shortcut").tag(DeckButton.Kind.shortcut)
                Text("URL").tag(DeckButton.Kind.openURL)
                Text("System").tag(DeckButton.Kind.system)
                Text("Media").tag(DeckButton.Kind.media)
            }
            switch button.kind {
            case .openApp:
                if apps.isEmpty {
                    Text("Ask the Mac for apps from Deck after you are connected.")
                        .foregroundStyle(.secondary)
                    TextField("Bundle ID", text: $button.payload)
                        .textInputAutocapitalization(.never)
                } else {
                    Picker("Application", selection: $button.payload) {
                        ForEach(apps) { app in
                            Text(app.displayName).tag(app.bundleIdentifier)
                        }
                    }
                }
            case .shortcut:
                TextField("cmd+c", text: $button.payload)
                    .textInputAutocapitalization(.never)
            case .openURL:
                TextField("https://", text: $button.payload)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            case .system:
                Picker("Action", selection: $button.payload) {
                    ForEach(SystemAction.allCases, id: \.self) { action in
                        Text(action.title).tag(action.rawValue)
                    }
                }
            case .media:
                TextField("playPause", text: $button.payload)
            case .presentation:
                TextField("next", text: $button.payload)
            }
        }
        .navigationTitle("Tile")
    }
}
