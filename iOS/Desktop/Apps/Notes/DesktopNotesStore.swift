import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Persistent, local-first notes workspace for Kamihi Desktop.
/// Note contents never leave the app unless the user explicitly exports/shares them.
@MainActor
public final class DesktopNotesStore: ObservableObject {
    public static let shared = DesktopNotesStore()

    public struct Note: Identifiable, Codable, Equatable {
        public let id: UUID
        public var title: String
        public var body: String
        /// Rich text is optional so existing v2 plain-text notes decode without migration loss.
        /// `body` remains a plain-text mirror for search, previews and compatibility bridges.
        public var richBody: AttributedString?
        public var updatedAt: Date

        public init(
            id: UUID = UUID(),
            title: String = "Untitled Note",
            body: String = "",
            richBody: AttributedString? = nil,
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.richBody = richBody
            self.updatedAt = updatedAt
        }
    }

    public enum InputTarget: String, Equatable {
        case search
        case title
        case body
    }

    private enum LocalAIAction: String {
        case summarize
        case rewrite
        case tasks
        case brainstorm

        var progressLabel: String {
            switch self {
            case .summarize: return "Summarizing"
            case .rewrite: return "Rewriting"
            case .tasks: return "Extracting tasks"
            case .brainstorm: return "Brainstorming"
            }
        }

        var sectionTitle: String {
            switch self {
            case .summarize: return "Local AI Summary"
            case .rewrite: return "Local AI Rewrite"
            case .tasks: return "Local AI Tasks"
            case .brainstorm: return "Local AI Ideas"
            }
        }

        var instruction: String {
            switch self {
            case .summarize:
                return "Summarize the note clearly and concisely. Preserve important decisions, names, dates, and open questions."
            case .rewrite:
                return "Rewrite the note to be clearer and better organized while preserving its meaning. Do not invent facts."
            case .tasks:
                return "Extract concrete action items from the note. Return a short checklist. Do not invent tasks that are not supported by the note."
            case .brainstorm:
                return "Suggest useful next ideas based only on the note's context. Clearly separate suggestions from facts already present in the note."
            }
        }
    }

    @Published public var notes: [Note] = [] {
        didSet { save() }
    }

    @Published public var activeNoteID: UUID? {
        didSet { saveActiveSelection() }
    }
    @Published public var text: String = ""
    @Published public var searchQuery: String = ""
    @Published public private(set) var inputTarget: InputTarget = .body
    @Published public private(set) var localAIStatus: String = ""
    @Published public private(set) var isLocalAIWorking = false

    private let storageKey = "kamihi.desktop.notes.v2"
    private let activeNoteStorageKey = "kamihi.desktop.notes.active.v1"

    private init() {
        // A successfully decoded empty array is a valid user state: it means the
        // user deliberately deleted every note. Seed the welcome note only when
        // there is no valid persisted collection at all, never merely because the
        // restored collection happens to be empty.
        if load() {
            restoreActiveSelection()
        } else {
            seedWelcomeNote()
        }
    }

    public var activeNote: Note? {
        get { notes.first(where: { $0.id == activeNoteID }) }
        set {
            guard let newValue, let idx = notes.firstIndex(where: { $0.id == newValue.id }) else { return }
            notes[idx] = newValue
        }
    }

    /// The UI and software-pointer hit-testing must consume the same filtered,
    /// newest-first list. Keeping this in the shared store prevents a search result
    /// row from selecting a different unfiltered note behind the scenes.
    public var visibleNotes: [Note] {
        let sorted = notes.sorted { $0.updatedAt > $1.updatedAt }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
                || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    public func focus(_ target: InputTarget) {
        inputTarget = target
    }

    public func createNewNote() {
        let note = Note()
        notes.insert(note, at: 0)
        activeNoteID = note.id
        text = note.body
        localAIStatus = ""
        inputTarget = .body
    }

    public func select(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        activeNoteID = id
        text = activeNote?.body ?? ""
        localAIStatus = ""
        inputTarget = .body
    }

    public func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        if activeNoteID == id {
            activeNoteID = notes.first?.id
            text = activeNote?.body ?? ""
        }
        if activeNoteID == nil {
            inputTarget = .body
        }
        localAIStatus = ""
    }

    public func deleteActiveNote() {
        if let id = activeNoteID {
            deleteNote(id: id)
        }
    }

    /// Returns persisted rich text when available, otherwise upgrades the existing
    /// plain-text body in memory without changing the user's content.
    public func attributedBody(for id: UUID) -> AttributedString {
        guard let note = notes.first(where: { $0.id == id }) else { return AttributedString() }
        return note.richBody ?? AttributedString(note.body)
    }

    /// Rich text is stored locally while a synchronized plain-text mirror keeps
    /// search, previews and the phone keyboard bridge deterministic.
    public func updateAttributedBody(_ value: AttributedString, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[index]
        note.richBody = value
        note.body = String(value.characters)
        note.updatedAt = Date()
        notes[index] = note
        if activeNoteID == id {
            text = note.body
        }
    }

    /// Phone/hardware-keyboard bridge for the non-interactive external-display
    /// editor. Search, title and body are distinct focus targets so clicking a
    /// search/title field can never silently edit the note body instead.
    public func appendToFocusedField(_ value: String) {
        guard !value.isEmpty else { return }
        switch inputTarget {
        case .search:
            searchQuery.append(value)
        case .title:
            guard let id = activeNoteID,
                  let index = notes.firstIndex(where: { $0.id == id }) else { return }
            notes[index].title.append(value)
            notes[index].updatedAt = Date()
        case .body:
            appendToActiveBody(value)
        }
    }

    public func deleteBackwardFromFocusedField() {
        switch inputTarget {
        case .search:
            guard !searchQuery.isEmpty else { return }
            searchQuery.removeLast()
        case .title:
            guard let id = activeNoteID,
                  let index = notes.firstIndex(where: { $0.id == id }),
                  !notes[index].title.isEmpty else { return }
            notes[index].title.removeLast()
            notes[index].updatedAt = Date()
        case .body:
            deleteBackwardFromActiveBody()
        }
    }

    public func pressEnterInFocusedField() {
        switch inputTarget {
        case .search:
            if let first = visibleNotes.first {
                select(first.id)
            } else {
                inputTarget = .body
            }
        case .title:
            inputTarget = .body
        case .body:
            if !handleTrailingSlashCommand() {
                insertNewlineIntoActiveBody()
            }
        }
    }

    /// Compatibility/body-specific bridge used by existing integrations. Appending
    /// through the phone/hardware keyboard preserves any rich formatting that was
    /// already created by the iOS 26 attributed TextEditor.
    public func appendToActiveBody(_ value: String) {
        guard !value.isEmpty, let id = activeNoteID else { return }
        var rich = attributedBody(for: id)
        rich.append(AttributedString(value))
        updateAttributedBody(rich, for: id)
    }

    public func deleteBackwardFromActiveBody() {
        guard let id = activeNoteID else { return }
        var rich = attributedBody(for: id)
        guard rich.startIndex != rich.endIndex else { return }
        let last = rich.characters.index(before: rich.endIndex)
        rich.removeSubrange(last..<rich.endIndex)
        updateAttributedBody(rich, for: id)
    }

    public func insertNewlineIntoActiveBody() {
        appendToActiveBody("\n")
    }

    /// Notion-style slash commands are intentionally local and deterministic.
    /// Block/template commands never call a service. AI commands explicitly route
    /// only through Apple's on-device SystemLanguageModel when it is available.
    @discardableResult
    private func handleTrailingSlashCommand() -> Bool {
        guard let id = activeNoteID else { return false }
        var rich = attributedBody(for: id)
        let plain = String(rich.characters)
        let lineStart = plain.lastIndex(of: "\n").map { plain.index(after: $0) } ?? plain.startIndex
        let command = plain[lineStart...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard command.hasPrefix("/") else { return false }

        let replacement: String?
        switch command {
        case "/todo":
            replacement = "☐ "
        case "/bullet":
            replacement = "• "
        case "/number":
            replacement = "1. "
        case "/quote":
            replacement = "❯ "
        case "/code":
            replacement = "```\n\n```"
        case "/divider":
            replacement = "────────────────────────"
        case "/meeting":
            replacement = """
            Meeting · \(Date.now.formatted(date: .abbreviated, time: .shortened))

            Agenda
            • 

            Notes

            Actions
            ☐ 
            """
        case "/project":
            replacement = """
            Project

            Goal

            Status
            • 

            Next actions
            ☐ 

            Notes
            """
        case "/daily":
            replacement = """
            \(Date.now.formatted(date: .long, time: .omitted))

            Focus
            • 

            Tasks
            ☐ 

            Notes
            """
        case "/help":
            replacement = """
            Local block commands
            /todo  /bullet  /number  /quote  /code  /divider
            /meeting  /project  /daily

            On-device AI commands
            /summarize  /rewrite  /tasks  /brainstorm
            """
        case "/summarize", "/rewrite", "/tasks", "/brainstorm":
            replacement = ""
        default:
            return false
        }

        let characterOffset = plain.distance(from: plain.startIndex, to: lineStart)
        let richStart = rich.characters.index(rich.startIndex, offsetBy: characterOffset)
        rich.replaceSubrange(richStart..<rich.endIndex, with: AttributedString(replacement ?? ""))
        updateAttributedBody(rich, for: id)

        if let action = LocalAIAction(rawValue: String(command.dropFirst())) {
            Task { await runLocalAI(action, noteID: id) }
        }
        return true
    }

    /// Runs only Apple's on-device foundation model. There is deliberately no
    /// URLSession, web endpoint, Private Cloud Compute model, token logging, or
    /// cloud fallback in this path. If Apple Intelligence is unavailable, the note
    /// stays local and unchanged and the UI reports that limitation.
    private func runLocalAI(_ action: LocalAIAction, noteID: UUID) async {
        guard let note = notes.first(where: { $0.id == noteID }) else { return }
        let fullSource = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullSource.isEmpty else {
            localAIStatus = "Add some note content before using local AI."
            return
        }

        isLocalAIWorking = true
        localAIStatus = "\(action.progressLabel) on device…"
        defer { isLocalAIWorking = false }

        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            localAIStatus = "On-device Apple Intelligence is unavailable on this device."
            return
        }

        // Bound extremely large scratchpads before prompting so a local request
        // does not unnecessarily exceed the device model's context window.
        let source = String(fullSource.prefix(12_000))
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are the private, local writing assistant inside Kamihi Notes.
            Work only with the note supplied by the user. Never claim external facts,
            web access, cloud access, or knowledge that is not present in the note.
            Keep the result practical and concise.
            """
        )

        do {
            let response = try await session.respond(to: """
            \(action.instruction)

            NOTE:
            \(source)
            """)
            appendLocalAIResult(response.content, action: action, noteID: noteID)
            localAIStatus = "Added \(action.sectionTitle.lowercased()) · on device"
        } catch {
            localAIStatus = "Local AI couldn't finish this request."
        }
        #else
        localAIStatus = "On-device Apple Intelligence isn't available in this build."
        #endif
    }

    private func appendLocalAIResult(_ result: String, action: LocalAIAction, noteID: UUID) {
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, notes.contains(where: { $0.id == noteID }) else { return }
        var rich = attributedBody(for: noteID)
        if !rich.characters.isEmpty {
            rich.append(AttributedString("\n\n"))
        }
        rich.append(AttributedString("\(action.sectionTitle)\n\(trimmed)"))
        updateAttributedBody(rich, for: noteID)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func saveActiveSelection() {
        if let activeNoteID {
            UserDefaults.standard.set(activeNoteID.uuidString, forKey: activeNoteStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeNoteStorageKey)
        }
    }

    /// Returns true whenever a valid collection was restored, including an empty
    /// collection. That distinction is what makes delete-all survive app relaunch.
    private func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Note].self, from: data) else {
            return false
        }
        notes = saved
        return true
    }

    private func restoreActiveSelection() {
        if let rawID = UserDefaults.standard.string(forKey: activeNoteStorageKey),
           let id = UUID(uuidString: rawID),
           notes.contains(where: { $0.id == id }) {
            activeNoteID = id
            text = notes.first(where: { $0.id == id })?.body ?? ""
            return
        }

        activeNoteID = notes.first?.id
        text = activeNote?.body ?? ""
    }

    private func seedWelcomeNote() {
        let defaultNote = Note(
            title: "Welcome to Kamihi Notes",
            body: "This is your private local workspace. Type /help on a new line to see local blocks, templates, and on-device AI commands."
        )
        notes = [defaultNote]
        activeNoteID = defaultNote.id
        text = defaultNote.body
    }
}
