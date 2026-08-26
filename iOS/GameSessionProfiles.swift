import SwiftUI

struct GameSessionProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var appName: String
    var bundleIdentifier: String
    var controllerProfile: ControllerProfile
    var mapping: ControllerMapping
    var layout: ControllerLayout
    var gameMapping: GameMapping
    var deadZone: Double
    var sensitivity: Double
    var haptics: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        appName: String = "",
        bundleIdentifier: String = "",
        controllerProfile: ControllerProfile,
        mapping: ControllerMapping,
        layout: ControllerLayout,
        gameMapping: GameMapping,
        deadZone: Double,
        sensitivity: Double,
        haptics: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.controllerProfile = controllerProfile
        self.mapping = mapping
        self.layout = layout
        self.gameMapping = gameMapping
        self.deadZone = deadZone
        self.sensitivity = sensitivity
        self.haptics = haptics
        self.updatedAt = updatedAt
    }

    var subtitle: String {
        let target = appName.isEmpty ? "No app launch" : appName
        return "\(target) • \(layout.rawValue.capitalized) • \(String(format: "%.2f×", sensitivity))"
    }

    static let fpsStarter = GameSessionProfile(
        id: UUID(uuidString: "B25BFD1D-2D2A-4B3C-B4EA-60E75E994011")!,
        name: "FPS Default",
        controllerProfile: .gaming,
        mapping: .gaming,
        layout: .fps,
        gameMapping: .fps,
        deadZone: 0.10,
        sensitivity: 1.0,
        haptics: true
    )
}

enum GameSessionStore {
    private static let key = "gameSessionProfilesV2"
    private static let limit = 24

    static func load() -> [GameSessionProfile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GameSessionProfile].self, from: data),
              decoded.isEmpty == false else {
            return [.fpsStarter]
        }
        return Array(decoded.prefix(limit))
    }

    static func save(_ profiles: [GameSessionProfile]) {
        guard let data = try? JSONEncoder().encode(Array(profiles.prefix(limit))) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
enum GameSessionLauncher {
    static func apply(_ profile: GameSessionProfile, session: RemoteSession, launchApp: Bool = true) {
        // Release anything held under the old mapping before changing the host mapping.
        session.sendController(.neutral)

        session.preferences.controllerProfile = profile.controllerProfile
        session.preferences.controllerMapping = profile.mapping
        session.preferences.controllerLayout = profile.layout
        session.preferences.gameMapping = profile.gameMapping
        session.preferences.stickDeadZone = min(max(profile.deadZone, 0.04), 0.30)
        session.preferences.stickSensitivity = min(max(profile.sensitivity, 0.5), 2.0)
        session.preferences.controllerHaptics = profile.haptics
        session.preferences.save()
        session.syncControllerConfig()

        if launchApp, profile.bundleIdentifier.isEmpty == false {
            session.sendAcknowledged(
                .openApp(bundleID: profile.bundleIdentifier),
                title: "Launch \(profile.appName.isEmpty ? profile.name : profile.appName)"
            )
        }

        session.flashAction("Game Session\n\(profile.name)", success: true)
        Haptics.gesture()
    }

    static func snapshot(name: String, app: HostAppEntry?, session: RemoteSession) -> GameSessionProfile {
        GameSessionProfile(
            name: name,
            appName: app?.displayName ?? "",
            bundleIdentifier: app?.bundleIdentifier ?? "",
            controllerProfile: session.preferences.controllerProfile,
            mapping: session.preferences.controllerMapping,
            layout: session.preferences.controllerLayout,
            gameMapping: session.preferences.gameMapping,
            deadZone: session.preferences.stickDeadZone,
            sensitivity: session.preferences.stickSensitivity,
            haptics: session.preferences.controllerHaptics
        )
    }
}

struct GameSessionManagerSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    @Binding var profiles: [GameSessionProfile]
    @Binding var selectedProfileID: String

    @State private var sessionName = ""
    @State private var selectedBundleID = ""

    private var sortedApps: [HostAppEntry] {
        session.hostApps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var selectedHostApp: HostAppEntry? {
        session.hostApps.first(where: { $0.bundleIdentifier == selectedBundleID })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Saved Game Sessions") {
                    ForEach(profiles) { profile in
                        Button {
                            selectedProfileID = profile.id.uuidString
                            GameSessionLauncher.apply(profile, session: session)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: profile.bundleIdentifier.isEmpty ? "gamecontroller.fill" : "play.rectangle.fill")
                                    .foregroundStyle(.cyan)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .foregroundStyle(.primary)
                                    Text(profile.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if selectedProfileID == profile.id.uuidString {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let deleted = offsets.map { profiles[$0].id.uuidString }
                        profiles.remove(atOffsets: offsets)
                        if deleted.contains(selectedProfileID) {
                            selectedProfileID = ""
                        }
                        GameSessionStore.save(profiles)
                    }
                    .onMove { source, destination in
                        profiles.move(fromOffsets: source, toOffset: destination)
                        GameSessionStore.save(profiles)
                    }
                }

                Section {
                    TextField("Session name, e.g. Minecraft", text: $sessionName)

                    Picker("Launch app", selection: $selectedBundleID) {
                        Text("Do not launch an app").tag("")
                        ForEach(sortedApps) { app in
                            Text(app.displayName).tag(app.bundleIdentifier)
                        }
                    }

                    LabeledContent("Profile", value: session.preferences.controllerProfile.title)
                    LabeledContent("Layout", value: session.preferences.controllerLayout.rawValue.capitalized)
                    LabeledContent("Dead zone", value: String(format: "%.2f", session.preferences.stickDeadZone))
                    LabeledContent("Sensitivity", value: String(format: "%.2f×", session.preferences.stickSensitivity))
                    LabeledContent("Haptics", value: session.preferences.controllerHaptics ? "On" : "Off")

                    Button {
                        saveCurrentSetup()
                    } label: {
                        Label("Save Game Session", systemImage: "plus.circle.fill")
                    }
                    .disabled(cleanName.isEmpty)
                } header: {
                    Text("Save Current Setup")
                } footer: {
                    Text("Tune the controller in Settings first, then save that exact mapping, layout and stick feel here. Selecting the session restores everything in one tap and can launch its Mac app.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Game Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        GameSessionStore.save(profiles)
                        dismiss()
                    }
                }
            }
            .onAppear {
                session.send(.requestAppList)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cleanName: String {
        sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveCurrentSetup() {
        guard cleanName.isEmpty == false else { return }

        let profile = GameSessionLauncher.snapshot(
            name: cleanName,
            app: selectedHostApp,
            session: session
        )
        profiles.append(profile)
        selectedProfileID = profile.id.uuidString
        GameSessionStore.save(profiles)
        sessionName = ""
        selectedBundleID = ""
        Haptics.gesture()
    }
}
