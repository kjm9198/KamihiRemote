import SwiftUI

struct GameSessionProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var appName: String
    var bundleIdentifier: String
    var gameMapping: GameMapping
    var mapping: ControllerMapping
    var layout: ControllerLayout
    var deadZone: Double
    var sensitivity: Double
    var haptics: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        appName: String = "",
        bundleIdentifier: String = "",
        gameMapping: GameMapping,
        mapping: ControllerMapping,
        layout: ControllerLayout,
        deadZone: Double,
        sensitivity: Double,
        haptics: Bool = true
    ) {
        self.id = id
        self.name = name
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.gameMapping = gameMapping
        self.mapping = mapping
        self.layout = layout
        self.deadZone = deadZone
        self.sensitivity = sensitivity
        self.haptics = haptics
    }

    var subtitle: String {
        let app = appName.isEmpty ? "Any game" : appName
        return "\(app) • \(gameMapping.title) • \(layout.title)"
    }

    static let fpsPrecision = GameSessionProfile(
        id: "starter-fps",
        name: "FPS Precision",
        gameMapping: .fps,
        mapping: .gaming,
        layout: .fps,
        deadZone: 0.08,
        sensitivity: 1.15
    )

    static let platformer = GameSessionProfile(
        id: "starter-platformer",
        name: "Platformer",
        gameMapping: .platformer,
        mapping: platformerMapping,
        layout: .standard,
        deadZone: 0.10,
        sensitivity: 1.0
    )

    static let racing = GameSessionProfile(
        id: "starter-racing",
        name: "Racing",
        gameMapping: .racing,
        mapping: racingMapping,
        layout: .racing,
        deadZone: 0.06,
        sensitivity: 0.9
    )

    static let starters: [GameSessionProfile] = [.fpsPrecision, .platformer, .racing]

    private static var platformerMapping: ControllerMapping {
        var mapping = ControllerMapping.gaming
        mapping.profile = .custom
        mapping.a = .key(code: 49, title: "Jump (Space)")
        mapping.b = .key(code: 53, title: "Back / Pause (Escape)")
        mapping.x = .key(code: 14, title: "Interact (E)")
        mapping.y = .key(code: 3, title: "Ability (F)")
        mapping.l1 = .key(code: 12, title: "Ability 1 (Q)")
        mapping.r1 = .key(code: 15, title: "Ability 2 (R)")
        mapping.l2 = .key(code: 56, title: "Sprint (Shift)")
        mapping.r2 = .key(code: 49, title: "Jump (Space)")
        mapping.leftStick = .arrows
        mapping.rightStick = .none
        return mapping
    }

    private static var racingMapping: ControllerMapping {
        var mapping = ControllerMapping.gaming
        mapping.profile = .custom
        mapping.a = .key(code: 49, title: "Handbrake (Space)")
        mapping.b = .key(code: 53, title: "Pause (Escape)")
        mapping.x = .key(code: 14, title: "Interact (E)")
        mapping.y = .key(code: 3, title: "Camera (F)")
        mapping.l1 = .key(code: 123, title: "Look Left")
        mapping.r1 = .key(code: 124, title: "Look Right")
        mapping.l2 = .key(code: 1, title: "Brake / Reverse (S)")
        mapping.r2 = .key(code: 13, title: "Accelerate (W)")
        mapping.leftStick = .arrows
        mapping.rightStick = .mouse
        return mapping
    }
}

enum GameSessionStore {
    private static let key = "gameSessionProfilesV1"

    static func load() -> [GameSessionProfile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GameSessionProfile].self, from: data),
              decoded.isEmpty == false else {
            return GameSessionProfile.starters
        }
        return decoded
    }

    static func save(_ profiles: [GameSessionProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
enum GameSessionLauncher {
    static func apply(_ profile: GameSessionProfile, session: RemoteSession, launchApp: Bool = true) {
        session.sendController(.neutral)
        session.preferences.controllerProfile = profile.mapping.profile
        session.preferences.controllerMapping = profile.mapping
        session.preferences.controllerLayout = profile.layout
        session.preferences.gameMapping = profile.gameMapping
        session.preferences.stickDeadZone = min(max(profile.deadZone, 0.04), 0.30)
        session.preferences.stickSensitivity = min(max(profile.sensitivity, 0.5), 2.0)
        session.preferences.controllerHaptics = profile.haptics
        session.syncControllerConfig()
        session.preferences.save()

        if launchApp, profile.bundleIdentifier.isEmpty == false {
            session.sendAcknowledged(.openApp(bundleID: profile.bundleIdentifier), title: "Launch \(profile.appName.isEmpty ? profile.name : profile.appName)")
        }

        session.flashAction("Game Session\n\(profile.name)", success: true)
        Haptics.gesture()
    }

    static func snapshot(name: String, app: HostAppEntry?, session: RemoteSession) -> GameSessionProfile {
        GameSessionProfile(
            name: name,
            appName: app?.displayName ?? "",
            bundleIdentifier: app?.bundleIdentifier ?? "",
            gameMapping: session.preferences.gameMapping,
            mapping: session.preferences.controllerMapping,
            layout: session.preferences.controllerLayout,
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

    @State private var profileName = ""
    @State private var selectedBundleID = ""

    private var selectedHostApp: HostAppEntry? {
        session.hostApps.first(where: { $0.bundleIdentifier == selectedBundleID })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Game Sessions") {
                    ForEach(profiles) { profile in
                        Button {
                            selectedProfileID = profile.id
                            GameSessionLauncher.apply(profile, session: session)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: profile.bundleIdentifier.isEmpty ? "gamecontroller.fill" : "play.rectangle.fill")
                                    .foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .foregroundStyle(.primary)
                                    Text(profile.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if profile.id == selectedProfileID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let deletedIDs = offsets.map { profiles[$0].id }
                        profiles.remove(atOffsets: offsets)
                        if deletedIDs.contains(selectedProfileID) {
                            selectedProfileID = profiles.first?.id ?? ""
                        }
                        GameSessionStore.save(profiles)
                    }
                }

                Section("Save Current Controller Setup") {
                    TextField("Session name, e.g. Minecraft", text: $profileName)

                    Picker("Launch app", selection: $selectedBundleID) {
                        Text("Do not launch an app").tag("")
                        ForEach(session.hostApps) { app in
                            Text(app.displayName).tag(app.bundleIdentifier)
                        }
                    }

                    LabeledContent("Mapping", value: session.preferences.controllerMapping.profile.title)
                    LabeledContent("Layout", value: session.preferences.controllerLayout.title)
                    LabeledContent("Dead zone", value: String(format: "%.2f", session.preferences.stickDeadZone))
                    LabeledContent("Sensitivity", value: String(format: "%.2f×", session.preferences.stickSensitivity))

                    Button {
                        saveCurrentSetup()
                    } label: {
                        Label("Save Game Session", systemImage: "plus.circle.fill")
                    }
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Customize buttons, sticks and tuning first in Controller Settings, then save the exact setup here. Applying a session restores all of it in one tap.")
                }
            }
            .navigationTitle("Game Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                session.send(.requestAppList)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveCurrentSetup() {
        let cleanName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanName.isEmpty == false else { return }

        let profile = GameSessionLauncher.snapshot(name: cleanName, app: selectedHostApp, session: session)
        profiles.append(profile)
        selectedProfileID = profile.id
        GameSessionStore.save(profiles)
        profileName = ""
        selectedBundleID = ""
        Haptics.gesture()
    }
}
