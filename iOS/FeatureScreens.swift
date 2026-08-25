import SwiftUI

struct PresentationScreen: View {
    @EnvironmentObject private var session: RemoteSession

    private var isLaser: Bool { session.pointerMode == .presentationLaser }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.05
            Group {
                if landscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .padding(KamihiUI.pad)
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: KamihiUI.gap) {
            HStack {
                Text("PRESENTATION")
                    .font(KamihiUI.titleFont)
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                pointerModeControl
            }

            HStack(spacing: KamihiUI.gap) {
                bigButton("Previous", "chevron.left") { send(.previous) }
                bigButton("Next", "chevron.right") { send(.next) }
            }
            .frame(maxHeight: 96)

            PointerSurface(chrome: .minimal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))

            HStack(spacing: KamihiUI.gap) {
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
            .onChange(of: session.preferences.presentationProfile) { _, _ in
                session.preferences.save()
            }
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: KamihiUI.gap) {
            HStack {
                Text("PRESENTATION")
                    .font(KamihiUI.titleFont)
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                pointerModeControl
            }
            HStack(spacing: KamihiUI.gap) {
                bigButton("Previous", "chevron.left") { send(.previous) }
                bigButton("Next", "chevron.right") { send(.next) }
            }
            .frame(maxHeight: 120)
            PointerSurface(chrome: .minimal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
            HStack(spacing: KamihiUI.gap) {
                smallButton("Start", "play.fill") { send(.start) }
                smallButton("Black", "rectangle.fill") { send(.black) }
                smallButton("End", "xmark") { send(.end) }
            }
        }
    }

    private var pointerModeControl: some View {
        Picker("Pointer", selection: Binding(
            get: { isLaser ? 1 : 0 },
            set: { value in
                session.pointerMode = value == 1 ? .presentationLaser : .macCursor
                session.send(.laserVisible(value == 1))
            }
        )) {
            Text("Cursor").tag(0)
            Text("Laser").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 180)
        .accessibilityLabel("Pointer mode")
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 72)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusLarge))
        .accessibilityLabel(title)
    }

    private func smallButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, minHeight: KamihiUI.controlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
    }
}

struct MediaScreen: View {
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        VStack(spacing: 16) {
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
        .padding(KamihiUI.pad)
    }

    private func media(_ symbol: String, _ label: String, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
        .accessibilityLabel(label)
    }
}

struct DeckScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var showsAdd = false
    @State private var showsAppGallery = false
    @State private var showsDictate = false
    @State private var editing: DeckButton?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("DECK")
                    .font(KamihiUI.titleFont)
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let banner = session.actionBanner {
                    Text(banner)
                        .font(KamihiUI.captionFont)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                Button {
                    showsAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: KamihiUI.controlHeight, height: KamihiUI.controlHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Add deck action")
                Button("Edit") { session.showsDeckEditor = true }
                    .font(KamihiUI.captionFont)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityLabel("Edit deck")
            }
            .padding(.horizontal, KamihiUI.pad)
            .padding(.top, KamihiUI.pad)

            GeometryReader { geo in
                let trackpadHeight = max(140, geo.size.height * 0.38)
                let gridHeight = max(160, geo.size.height - trackpadHeight - 8)
                VStack(spacing: 8) {
                    let columns = max(3, min(4, max(1, Int(geo.size.width / 92))))
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: KamihiUI.gap), count: columns), spacing: KamihiUI.gap) {
                            ForEach(session.deck) { button in
                                Button { run(button) } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: button.symbol)
                                            .font(.system(size: 22, weight: .semibold))
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
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusMedium))
                                .accessibilityLabel(button.title)
                                .contextMenu {
                                    Button("Edit") { editing = button }
                                    Button("Remove", role: .destructive) { remove(button) }
                                }
                            }
                        }
                        .padding(.horizontal, KamihiUI.pad)
                        .padding(.bottom, 4)
                    }
                    .frame(height: gridHeight)

                    VStack(spacing: 4) {
                        Text("TRACKPAD")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.4))
                        PolishedTrackpadSurface(showDiagnostics: false)
                            .clipShape(RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: KamihiUI.radiusLarge, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, KamihiUI.pad)
                    .padding(.bottom, KamihiUI.pad)
                    .frame(height: trackpadHeight)
                }
            }
        }
        .confirmationDialog("Choose an Action", isPresented: $showsAdd, titleVisibility: .visible) {
            Button("Application") {
                session.send(.requestAppList)
                showsAppGallery = true
            }
            Button("Shortcut") { add(.shortcut, title: "Shortcut", symbol: "command", payload: "cmd+c") }
            Button("Dictate Prompt") { add(.dictate, title: "Dictate", symbol: "mic.fill", payload: "prompt") }
            Button("Website") { add(.openURL, title: "Website", symbol: "globe", payload: "https://") }
            Button("System") { add(.system, title: "Mission Control", symbol: "rectangle.3.group", payload: SystemAction.missionControl.rawValue) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showsAppGallery) {
            MacAppGallery { app in
                add(.openApp, title: app.displayName, symbol: "app", payload: app.bundleIdentifier)
                showsAppGallery = false
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $showsDictate) {
            DictatePromptSheet().environmentObject(session)
        }
        .sheet(isPresented: $session.showsDeckEditor) {
            DeckEditorSheet().environmentObject(session)
        }
        .onAppear {
            // One-time bump onto the agent deck if still on legacy Music/Safari layout.
            if session.deck.contains(where: { $0.id == "music" || $0.id == "safari" }),
               session.deck.contains(where: { $0.id == "dictate" }) == false {
                session.deck = DeckButton.defaultLayout
                DeckButton.save(session.deck)
            }
            #if DEBUG
            if session.uiTestShowDeckGallery {
                showsAppGallery = true
                session.uiTestShowDeckGallery = false
            }
            #endif
        }
        .sheet(item: $editing) { button in
            NavigationStack {
                DeckTileEditor(
                    button: Binding(
                        get: { session.deck.first(where: { $0.id == button.id }) ?? button },
                        set: { updated in
                            if let idx = session.deck.firstIndex(where: { $0.id == updated.id }) {
                                session.deck[idx] = updated
                                DeckButton.save(session.deck)
                            }
                        }
                    ),
                    apps: session.hostApps
                )
                .navigationTitle("Edit Tile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { editing = nil }
                    }
                }
            }
        }
    }

    private func add(_ kind: DeckButton.Kind, title: String, symbol: String, payload: String) {
        let tile = DeckButton(id: UUID().uuidString, title: title, symbol: symbol, kind: kind, payload: payload)
        session.deck.append(tile)
        DeckButton.save(session.deck)
        Haptics.gesture()
    }

    private func remove(_ button: DeckButton) {
        session.deck.removeAll { $0.id == button.id }
        DeckButton.save(session.deck)
    }

    private func run(_ button: DeckButton) {
        switch button.kind {
        case .shortcut:
            session.sendAcknowledged(.shortcut(button.payload), title: button.title)
        case .openApp:
            session.sendAcknowledged(.openApp(bundleID: button.payload), title: button.title)
        case .openURL:
            session.sendAcknowledged(.openURL(button.payload), title: button.title)
        case .system:
            if let action = SystemAction(rawValue: button.payload) {
                session.sendAcknowledged(.system(action), title: button.title)
            } else {
                session.flashAction("\(button.title)\nUnknown action", success: false)
            }
        case .presentation:
            if let action = PresentationAction(rawValue: button.payload) {
                session.sendAcknowledged(.presentation(action: action, profile: session.preferences.presentationProfile), title: button.title)
            }
        case .media:
            if let action = MediaAction(rawValue: button.payload) {
                session.sendAcknowledged(.media(action), title: button.title)
            }
        case .dictate:
            showsDictate = true
        }
    }
}

struct MacAppGallery: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var onPick: (HostAppEntry) -> Void

    private var filtered: [HostAppEntry] {
        let apps = session.hostApps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return apps }
        return apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(q)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if session.hostApps.isEmpty {
                    Text("Waiting for Mac apps… Connect and try again.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { app in
                    Button {
                        onPick(app)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search apps")
            .navigationTitle("Choose an App")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") { session.send(.requestAppList) }
                }
            }
            .onAppear { session.send(.requestAppList) }
        }
    }
}

struct DeckEditorSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [DeckButton] = []

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
                Text("Dictate").tag(DeckButton.Kind.dictate)
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
                TextField("cmd+c or selectLine", text: $button.payload)
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
            case .dictate:
                Text("Opens mic dictation, then types the prompt on the Mac and presses Return.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tile")
    }
}
