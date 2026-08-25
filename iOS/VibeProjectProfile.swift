import Foundation
import SwiftUI

struct VibeProjectProfile: Codable, Equatable {
    static let autoDevToken = "__KAMIHI_AUTO_DEV__"
    static let autoVerifyToken = "__KAMIHI_AUTO_VERIFY__"

    var previewURL: String
    var devCommand: String
    var testCommand: String

    static let standard = VibeProjectProfile(
        previewURL: "http://localhost:3000",
        devCommand: autoDevToken,
        testCommand: autoVerifyToken
    )

    var usesAutomaticDevCommand: Bool { devCommand == Self.autoDevToken }
    var usesAutomaticVerifyCommand: Bool { testCommand == Self.autoVerifyToken }
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
            command: resolvedDevCommand(profile.devCommand),
            project: project,
            title: profile.usesAutomaticDevCommand ? "Auto Start Dev" : "Start Dev",
            session: session
        )
    }

    static func runTests(project: VoiceProject?, profile: VibeProjectProfile, session: RemoteSession) {
        runVisible(
            command: resolvedVerifyCommand(profile.testCommand),
            project: project,
            title: profile.usesAutomaticVerifyCommand ? "Auto Verify" : "Run Tests",
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
        echo ""
        echo "⚡ Kamihi Vibe • \(title)"
        echo "📁 $PWD"
        echo ""
        \(cleanCommand)
        """
        let encoded = Data(script.utf8).base64EncodedString()
        let safeID = project.id
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let temp = "/tmp/kamihi-vibe-\(safeID)-\(UUID().uuidString.prefix(8)).command"
        let launcher = "printf %s '\(encoded)' | /usr/bin/base64 -D > '\(temp)' && chmod +x '\(temp)' && open -a Terminal '\(temp)'"
        session.sendAcknowledged(.runCommand(launcher), title: title)
    }

    /// Resolve the default Dev action on the Mac instead of assuming every project is npm.
    /// Custom user commands bypass this completely.
    private static func resolvedDevCommand(_ configured: String) -> String {
        guard configured == VibeProjectProfile.autoDevToken else { return configured }
        return #"""
        set -e

        run_js_script() {
          local script="$1"
          if [ -f bun.lockb ] || [ -f bun.lock ]; then
            command -v bun >/dev/null 2>&1 || { echo "Bun lockfile found, but bun is not installed."; exit 127; }
            exec bun run "$script"
          elif [ -f pnpm-lock.yaml ]; then
            command -v pnpm >/dev/null 2>&1 || { echo "pnpm-lock.yaml found, but pnpm is not installed."; exit 127; }
            exec pnpm run "$script"
          elif [ -f yarn.lock ]; then
            command -v yarn >/dev/null 2>&1 || { echo "yarn.lock found, but yarn is not installed."; exit 127; }
            exec yarn "$script"
          else
            command -v npm >/dev/null 2>&1 || { echo "package.json found, but npm is not installed."; exit 127; }
            exec npm run "$script"
          fi
        }

        if [ -f package.json ]; then
          if command -v node >/dev/null 2>&1 && node -e 'const p=require("./package.json"); process.exit(p.scripts&&p.scripts.dev?0:1)' >/dev/null 2>&1; then
            echo "Detected JavaScript/TypeScript project → dev"
            run_js_script dev
          elif command -v node >/dev/null 2>&1 && node -e 'const p=require("./package.json"); process.exit(p.scripts&&p.scripts.start?0:1)' >/dev/null 2>&1; then
            echo "No dev script; using start"
            run_js_script start
          else
            echo "package.json has no dev/start script. Configure a custom Dev command in Vibe Actions."
            exit 64
          fi
        elif [ -f Package.swift ]; then
          echo "Detected Swift Package → swift run"
          exec swift run
        elif [ -f Cargo.toml ]; then
          echo "Detected Rust project → cargo run"
          exec cargo run
        elif [ -f go.mod ]; then
          echo "Detected Go project → go run ."
          exec go run .
        elif [ -f manage.py ]; then
          echo "Detected Django project → runserver"
          exec python3 manage.py runserver
        elif [ -f Makefile ] && grep -Eq '^dev:' Makefile; then
          echo "Detected Makefile dev target → make dev"
          exec make dev
        elif [ -f Makefile ] && grep -Eq '^run:' Makefile; then
          echo "Detected Makefile run target → make run"
          exec make run
        else
          echo "Kamihi could not detect a Dev command for this project."
          echo "Open Configure Vibe Actions and enter the command once; it will be remembered for this project."
          exit 64
        fi
        """#
    }

    /// Pick the strongest verification the repository advertises. For JS projects this prefers tests,
    /// then type-check, build, then lint so the button remains useful even when no test script exists.
    private static func resolvedVerifyCommand(_ configured: String) -> String {
        guard configured == VibeProjectProfile.autoVerifyToken else { return configured }
        return #"""
        set -e

        has_js_script() {
          command -v node >/dev/null 2>&1 && node -e 'const p=require("./package.json"); process.exit(p.scripts&&p.scripts[process.argv[1]]?0:1)' "$1" >/dev/null 2>&1
        }

        run_js_script() {
          local script="$1"
          if [ -f bun.lockb ] || [ -f bun.lock ]; then
            command -v bun >/dev/null 2>&1 || { echo "Bun lockfile found, but bun is not installed."; exit 127; }
            bun run "$script"
          elif [ -f pnpm-lock.yaml ]; then
            command -v pnpm >/dev/null 2>&1 || { echo "pnpm-lock.yaml found, but pnpm is not installed."; exit 127; }
            pnpm run "$script"
          elif [ -f yarn.lock ]; then
            command -v yarn >/dev/null 2>&1 || { echo "yarn.lock found, but yarn is not installed."; exit 127; }
            yarn "$script"
          else
            command -v npm >/dev/null 2>&1 || { echo "package.json found, but npm is not installed."; exit 127; }
            npm run "$script"
          fi
        }

        if [ -f package.json ]; then
          ran=0
          if has_js_script test; then
            echo "▶ test"
            run_js_script test
            ran=1
          fi
          if has_js_script typecheck; then
            echo "▶ typecheck"
            run_js_script typecheck
            ran=1
          elif has_js_script type-check; then
            echo "▶ type-check"
            run_js_script type-check
            ran=1
          fi
          if has_js_script build; then
            echo "▶ build"
            run_js_script build
            ran=1
          fi
          if has_js_script lint; then
            echo "▶ lint"
            run_js_script lint
            ran=1
          fi
          if [ "$ran" -eq 0 ]; then
            echo "No test/typecheck/build/lint script was found in package.json."
            exit 64
          fi
          echo ""
          echo "✅ Kamihi verification passed"
        elif [ -f Package.swift ]; then
          echo "Detected Swift Package → swift test"
          exec swift test
        elif [ -f Cargo.toml ]; then
          echo "Detected Rust project → cargo test"
          exec cargo test
        elif [ -f go.mod ]; then
          echo "Detected Go project → go test ./..."
          exec go test ./...
        elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -d tests ]; then
          if command -v pytest >/dev/null 2>&1; then
            echo "Detected Python tests → pytest"
            exec pytest
          elif command -v python3 >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
            echo "Detected Python tests → python3 -m pytest"
            exec python3 -m pytest
          else
            echo "Python project detected, but pytest is unavailable. Configure a custom Verify command if this project uses another runner."
            exit 127
          fi
        elif [ -f Makefile ] && grep -Eq '^test:' Makefile; then
          echo "Detected Makefile test target → make test"
          exec make test
        else
          echo "Kamihi could not detect a verification command for this project."
          echo "Open Configure Vibe Actions and enter the command once; it will be remembered for this project."
          exit 64
        fi
        """#
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
    @State private var automaticDev: Bool
    @State private var automaticVerify: Bool

    init(project: VoiceProject) {
        self.project = project
        let profile = VibeProjectProfileStore.load(projectID: project.id)
        _previewURL = State(initialValue: profile.previewURL)
        _devCommand = State(initialValue: profile.usesAutomaticDevCommand ? "" : profile.devCommand)
        _testCommand = State(initialValue: profile.usesAutomaticVerifyCommand ? "" : profile.testCommand)
        _automaticDev = State(initialValue: profile.usesAutomaticDevCommand)
        _automaticVerify = State(initialValue: profile.usesAutomaticVerifyCommand)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name", value: project.name)
                    LabeledContent("Path", value: project.path)
                } header: {
                    Text("Project")
                }

                Section {
                    TextField("http://localhost:3000", text: $previewURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Preview")
                } footer: {
                    Text("Used by the Preview button in Vibe Hub.")
                }

                Section {
                    Toggle("Auto-detect Dev command", isOn: $automaticDev)
                    if automaticDev == false {
                        TextField("e.g. pnpm dev", text: $devCommand)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Auto-detect Verify command", isOn: $automaticVerify)
                    if automaticVerify == false {
                        TextField("e.g. pnpm test", text: $testCommand)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Commands")
                } footer: {
                    Text("Auto mode detects Bun, pnpm, Yarn, npm, Swift Package Manager, Cargo, Go, Python and Makefile projects. Custom commands always take priority and run visibly in Terminal.")
                }

                Section {
                    Button("Reset to Smart Defaults", role: .destructive) {
                        VibeProjectProfileStore.reset(projectID: project.id)
                        let defaults = VibeProjectProfile.standard
                        previewURL = defaults.previewURL
                        devCommand = ""
                        testCommand = ""
                        automaticDev = true
                        automaticVerify = true
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
                            devCommand: automaticDev
                                ? VibeProjectProfile.autoDevToken
                                : devCommand.trimmingCharacters(in: .whitespacesAndNewlines),
                            testCommand: automaticVerify
                                ? VibeProjectProfile.autoVerifyToken
                                : testCommand.trimmingCharacters(in: .whitespacesAndNewlines)
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
