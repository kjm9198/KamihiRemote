import Foundation
import SwiftUI

struct VibeProjectProfile: Codable, Equatable {
    var previewURL: String
    var devCommand: String
    var testCommand: String

    static let standard = VibeProjectProfile(
        previewURL: "http://localhost:3000",
        devCommand: "npm run dev",
        testCommand: "npm test"
    )
}

enum VibeProjectProfileStore {
    private static let key = "vibeProjectProfilesV1"

    static func load(projectID: String?) -> VibeProjectProfile {
        guard let projectID, projectID.isEmpty == false else { return .standard }
        return loadAll()[projectID] ?? .standard
    }

    static func save(_ profile: VibeProjectProfile, projectID: String) {
        guard projectID.isEmpty == false else { return }
        var profiles = loadAll()
        profiles[projectID] = profile
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset(projectID: String) {
        var profiles = loadAll()
        profiles.removeValue(forKey: projectID)
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadAll() -> [String: VibeProjectProfile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profiles = try? JSONDecoder().decode([String: VibeProjectProfile].self, from: data) else {
            return [:]
        }
        return profiles
    }
}

@MainActor
enum VibeProjectCommandRunner {
    static func openPreview(project: VoiceProject?, profile: VibeProjectProfile, session: RemoteSession) {
        let raw = profile.previewURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false else {
            session.flashAction("No preview URL configured", success: false)
            return
        }
        session.sendAcknowledged(.openURL(raw), title: "Preview")
    }

    static func runDev(project: VoiceProject?, profile: VibeProjectProfile, session: RemoteSession) {
        runVisible(
            command: profile.devCommand,
            project: project,
            title: "Start Dev",
            session: session
        )
    }

    static func runTests(project: VoiceProject?, profile: VibeProjectProfile, session: RemoteSession) {
        runVisible(
            command: profile.testCommand,
            project: project,
            title: "Run Tests",
            session: session
        )
    }

    static func stopFrontTerminalCommand(session: RemoteSession) {
        session.sendAcknowledged(.runCommand("open -a Terminal"), title: "Focus Terminal")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let controlFlag: UInt64 = 1 << 18
            session.send(.keyDown(code: 8, flags: controlFlag))
            session.send(.keyUp(code: 8, flags: controlFlag))
            session.flashAction("Stop command sent", success: true)
        }
    }

    private static func runVisible(
        command: String,
        project: VoiceProject?,
        title: String,
        session: RemoteSession
    ) {
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCommand.isEmpty == false else {
            session.flashAction("No command configured", success: false)
            return
        }
        guard let project else {
            session.flashAction("Select a project first", success: false)
            return
        }

        let script = """
        #!/bin/zsh
        cd \(shellPath(project.path)) || exit 1
        \(cleanCommand)
        """
        let encoded = Data(script.utf8).base64EncodedString()
        let safeID = project.id
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let temp = "/tmp/kamihi-vibe-\(safeID)-\(UUID().uuidString.prefix(8)).command"
        let launcher = "printf %s '\(encoded)' | /usr/bin/base64 -D > '\(temp)' && chmod +x '\(temp)' && open -a Terminal '\(temp)'"
        session.sendAcknowledged(.runCommand(launcher), title: title)
    }

    private static func shellPath(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "~" { return "\"$HOME\"" }
        if value.hasPrefix("~/") {
            return "\"$HOME\"/" + shellQuote(String(value.dropFirst(2)))
        }
        return shellQuote(value)
    }

    private static func shellQuote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

struct VibeProjectProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: VoiceProject

    @State private var previewURL: String
    @State private var devCommand: String
    @State private var testCommand: String

    init(project: VoiceProject) {
        self.project = project
        let profile = VibeProjectProfileStore.load(projectID: project.id)
        _previewURL = State(initialValue: profile.previewURL)
        _devCommand = State(initialValue: profile.devCommand)
        _testCommand = State(initialValue: profile.testCommand)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    LabeledContent("Name", value: project.name)
                    LabeledContent("Path", value: project.path)
                }

                Section("Preview") {
                    TextField("http://localhost:3000", text: $previewURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Used by the Preview button in Vibe Hub.")
                }

                Section("Commands") {
                    TextField("npm run dev", text: $devCommand)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("npm test", text: $testCommand)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Commands run visibly in Terminal from this project's folder, so you can see logs and failures immediately.")
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        VibeProjectProfileStore.reset(projectID: project.id)
                        let defaults = VibeProjectProfile.standard
                        previewURL = defaults.previewURL
                        devCommand = defaults.devCommand
                        testCommand = defaults.testCommand
                    }
                }
            }
            .navigationTitle("Vibe Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let profile = VibeProjectProfile(
                            previewURL: previewURL.trimmingCharacters(in: .whitespacesAndNewlines),
                            devCommand: devCommand.trimmingCharacters(in: .whitespacesAndNewlines),
                            testCommand: testCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        VibeProjectProfileStore.save(profile, projectID: project.id)
                        Haptics.gesture()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
