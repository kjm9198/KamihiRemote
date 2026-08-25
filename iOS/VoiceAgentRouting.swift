import Foundation
import SwiftUI

enum VoiceAgentDestination: String, CaseIterable, Identifiable, Codable {
    case antigravity
    case cursor
    case chatGPT
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .cursor: return "Cursor"
        case .chatGPT: return "ChatGPT"
        case .claude: return "Claude"
        }
    }

    var symbol: String {
        switch self {
        case .antigravity: return "sparkles"
        case .cursor: return "cursorarrow.rays"
        case .chatGPT: return "bubble.left.and.bubble.right.fill"
        case .claude: return "brain.head.profile"
        }
    }

    var applicationName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .cursor: return "Cursor"
        case .chatGPT: return "ChatGPT"
        case .claude: return "Claude"
        }
    }

    var supportsProjectFolders: Bool {
        self == .antigravity || self == .cursor
    }
}

struct VoiceProject: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var path: String

    init(id: String = UUID().uuidString, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }

    static let defaults: [VoiceProject] = [
        VoiceProject(id: "kamihi-remote", name: "KamihiRemote", path: "~/KamihiRemote"),
        VoiceProject(id: "sproutsly", name: "Sproutsly", path: "~/Documents/VSC Projects/Sproutsly"),
        VoiceProject(id: "bar-hanoi", name: "Bar Ha Noi", path: "~/Documents/Work Websites/Bar Ha Noi"),
        VoiceProject(id: "bemy-matcha", name: "BeMyMatcha", path: "~/Documents/Work Websites/BeMyMatcha"),
        VoiceProject(id: "vietnam-quan", name: "Vietnam Quan", path: "~/Documents/Work Websites/Vietnam Quan and Mart"),
        VoiceProject(id: "yuki", name: "Yuki By WOA", path: "~/Documents/Work Websites/Yuki By WOA"),
        VoiceProject(id: "kamihi-tracker", name: "Kamihi Studio Tracker", path: "~/Documents/Work Websites/Kamihi Studio Tracker"),
        VoiceProject(id: "asian-house", name: "Asian House", path: "~/Documents/Work Websites/Asian House"),
        VoiceProject(id: "hello-vietnam", name: "Hello Vietnam", path: "~/Documents/Work Websites/Hello Vietnam"),
        VoiceProject(id: "portfolio", name: "Portfolio", path: "~/Documents/VSC Projects/Portfolio"),
        VoiceProject(id: "calorie-tracking", name: "Calorie Tracking", path: "~/Documents/VSC Projects/Calorie Tracking"),
        VoiceProject(id: "bubella", name: "Bubella", path: "~/Documents/Work Websites/Bubella"),
        VoiceProject(id: "kas", name: "Kas", path: "~/Documents/VSC Projects/Kas")
    ]
}

enum VoiceProjectStore {
    private static let key = "voiceAgentProjectsV2"

    static func load() -> [VoiceProject] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VoiceProject].self, from: data),
              decoded.isEmpty == false else {
            return VoiceProject.defaults
        }
        return decoded
    }

    static func save(_ projects: [VoiceProject]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
enum VoiceAgentRouter {
    static func switchWorkspace(to project: VoiceProject, destination: VoiceAgentDestination = .antigravity, session: RemoteSession) {
        let app = shellQuote(destination.applicationName)
        let path = shellPath(project.path)
        session.send(.runCommand("open -a \(app) \(path) || open -a \(shellQuote(destination.applicationName + " IDE")) \(path)"))
        session.flashAction("Switched to \(project.name)", success: true)
    }

    static func route(
        prompt: String,
        destination: VoiceAgentDestination,
        project: VoiceProject?,
        session: RemoteSession,
        status: @escaping (String) -> Void
    ) async {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPrompt.isEmpty == false else { return }

        let effectivePrompt: String
        if let project {
            effectivePrompt = "Project: \(project.name)\n\(cleanPrompt)"
        } else {
            effectivePrompt = cleanPrompt
        }

        switch destination {
        case .antigravity, .cursor:
            status("Opening \(destination.title)…")
            openCodingDestination(destination, project: project, session: session)
            await pause(850)

            status("Focusing agent…")
            session.send(.shortcut("cmd+l"))
            await pause(240)

            status("Sending prompt…")
            sendText(effectivePrompt, session: session)
            await pause(120)
            pressReturn(session)

        case .chatGPT:
            status("Opening ChatGPT…")
            if let app = bestHostApp(for: .chatGPT, in: session.hostApps) {
                session.send(.openApp(bundleID: app.bundleIdentifier))
            } else {
                session.send(.runCommand("open -a 'ChatGPT'"))
            }
            await pause(450)

            // ChatGPT for macOS: Option+Space opens/refocuses the quick chat bar.
            session.send(.shortcut("option+space"))
            await pause(360)

            status("Sending prompt…")
            sendText(effectivePrompt, session: session)
            await pause(120)
            pressReturn(session)

        case .claude:
            status("Opening Claude…")
            if let deepLink = claudeDeepLink(prompt: effectivePrompt) {
                session.send(.openURL(deepLink))
                await pause(650)
                status("Sending prompt…")
                pressReturn(session)
            } else {
                if let app = bestHostApp(for: .claude, in: session.hostApps) {
                    session.send(.openApp(bundleID: app.bundleIdentifier))
                } else {
                    session.send(.runCommand("open -a 'Claude'"))
                }
                await pause(450)
                session.send(.shortcut("cmd+n"))
                await pause(260)
                sendText(effectivePrompt, session: session)
                await pause(120)
                pressReturn(session)
            }
        }

        await pause(180)
        status("Sent to \(destination.title)")
        session.flashAction("Sent to \(destination.title)", success: true)
    }

    private static func openCodingDestination(
        _ destination: VoiceAgentDestination,
        project: VoiceProject?,
        session: RemoteSession
    ) {
        if let project, project.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let app = shellQuote(destination.applicationName)
            let path = shellPath(project.path)
            session.send(.runCommand("open -a \(app) \(path) || open -a \(shellQuote(destination.applicationName + " IDE")) \(path)"))
            return
        }

        if let hostApp = bestHostApp(for: destination, in: session.hostApps) {
            session.send(.openApp(bundleID: hostApp.bundleIdentifier))
        } else {
            session.send(.runCommand("open -a \(shellQuote(destination.applicationName)) || open -a \(shellQuote(destination.applicationName + " IDE"))"))
        }
    }

    private static func bestHostApp(
        for destination: VoiceAgentDestination,
        in apps: [HostAppEntry]
    ) -> HostAppEntry? {
        let needles: [String]
        switch destination {
        case .antigravity: needles = ["antigravity"]
        case .cursor: needles = ["cursor"]
        case .chatGPT: needles = ["chatgpt", "openai"]
        case .claude: needles = ["claude", "anthropic"]
        }

        return apps.first { app in
            let haystack = "\(app.displayName) \(app.bundleIdentifier)".lowercased()
            return needles.contains { haystack.contains($0) }
        }
    }

    private static func sendText(_ text: String, session: RemoteSession) {
        var buffer = ""

        func flush() {
            guard buffer.isEmpty == false else { return }
            session.send(.typeText(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in text {
            if character == " " {
                flush()
                session.send(.keyDown(code: 49, flags: 0))
                session.send(.keyUp(code: 49, flags: 0))
            } else if character == "\n" {
                flush()
                let shiftFlag: UInt64 = 1 << 17
                session.send(.keyDown(code: 36, flags: shiftFlag))
                session.send(.keyUp(code: 36, flags: shiftFlag))
            } else {
                buffer.append(character)
            }
        }
        flush()
    }

    private static func pressReturn(_ session: RemoteSession) {
        session.send(.keyDown(code: 36, flags: 0))
        session.send(.keyUp(code: 36, flags: 0))
    }

    private static func claudeDeepLink(prompt: String) -> String? {
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "claude.ai"
        components.path = "/new"
        components.queryItems = [URLQueryItem(name: "q", value: prompt)]
        return components.url?.absoluteString
    }

    private static func shellQuote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func shellPath(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "~" {
            return "\"$HOME\""
        }
        if value.hasPrefix("~/") {
            let remainder = String(value.dropFirst(2))
            return "\"$HOME\"/" + shellQuote(remainder)
        }
        return shellQuote(value)
    }

    private static func pause(_ milliseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}

struct VoiceProjectManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var projects: [VoiceProject]
    @Binding var selectedProjectID: String

    @State private var name = ""
    @State private var path = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Projects") {
                    Button {
                        selectedProjectID = ""
                        Haptics.touchTap()
                    } label: {
                        HStack {
                            Label("Current app only", systemImage: "macwindow")
                            Spacer()
                            if selectedProjectID.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }

                    ForEach(projects) { project in
                        Button {
                            selectedProjectID = project.id
                            Haptics.touchTap()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.name)
                                        .foregroundStyle(.primary)
                                    Text(project.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if selectedProjectID == project.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let deletedIDs = offsets.map { projects[$0].id }
                        projects.remove(atOffsets: offsets)
                        if deletedIDs.contains(selectedProjectID) {
                            selectedProjectID = projects.first?.id ?? ""
                        }
                        VoiceProjectStore.save(projects)
                    }
                }

                Section("Add project") {
                    TextField("Name", text: $name)
                    TextField("Mac path, e.g. ~/Sproutsly", text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        addProject()
                    } label: {
                        Label("Add Project", systemImage: "plus.circle.fill")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        VoiceProjectStore.save(projects)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addProject() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanName.isEmpty == false, cleanPath.isEmpty == false else { return }

        let project = VoiceProject(name: cleanName, path: cleanPath)
        projects.append(project)
        selectedProjectID = project.id
        VoiceProjectStore.save(projects)
        name = ""
        path = ""
        Haptics.gesture()
    }
}
