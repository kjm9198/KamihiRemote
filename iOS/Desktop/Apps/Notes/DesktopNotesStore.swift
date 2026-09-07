import Foundation

/// Persistent offline notes store for Kamihi Desktop.
@MainActor
public final class DesktopNotesStore: ObservableObject {
    public static let shared = DesktopNotesStore()

    public struct Note: Identifiable, Codable, Equatable {
        public let id: UUID
        public var title: String
        public var body: String
        public var updatedAt: Date

        public init(id: UUID = UUID(), title: String = "Untitled Note", body: String = "", updatedAt: Date = Date()) {
            self.id = id
            self.title = title
            self.body = body
            self.updatedAt = updatedAt
        }
    }

    public enum InputTarget: String, Equatable {
        case search
        case title
        case body
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
        inputTarget = .body
    }

    public func select(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        activeNoteID = id
        text = activeNote?.body ?? ""
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
    }

    public func deleteActiveNote() {
        if let id = activeNoteID {
            deleteNote(id: id)
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
            insertNewlineIntoActiveBody()
        }
    }

    /// Compatibility/body-specific bridge used by existing integrations.
    public func appendToActiveBody(_ value: String) {
        guard !value.isEmpty,
              let id = activeNoteID,
              let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].body.append(value)
        notes[index].updatedAt = Date()
        text = notes[index].body
    }

    public func deleteBackwardFromActiveBody() {
        guard let id = activeNoteID,
              let index = notes.firstIndex(where: { $0.id == id }),
              !notes[index].body.isEmpty else { return }
        notes[index].body.removeLast()
        notes[index].updatedAt = Date()
        text = notes[index].body
    }

    public func insertNewlineIntoActiveBody() {
        appendToActiveBody("\n")
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
            body: "This is your native offline scratchpad for thoughts, outlines, and code snippets."
        )
        notes = [defaultNote]
        activeNoteID = defaultNote.id
        text = defaultNote.body
    }
}
