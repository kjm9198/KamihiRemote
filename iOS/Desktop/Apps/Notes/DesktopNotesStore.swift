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

    @Published public private(set) var notes: [Note] = [] {
        didSet { save() }
    }

    @Published public private(set) var activeNoteID: UUID?
    /// Writable phone-editor bridge. Direct edits are folded back into the active
    /// note so the existing iPhone keyboard sheet remains compatible and durable.
    @Published public var text: String = "" {
        didSet {
            guard let id = activeNoteID,
                  let index = notes.firstIndex(where: { $0.id == id }),
                  notes[index].body != text else { return }
            notes[index].body = text
            notes[index].updatedAt = Date()
        }
    }

    private let storageKey = "kamihi.desktop.notes.v2"

    private init() {
        load()
        if notes.isEmpty {
            let defaultNote = Note(
                title: "Welcome to Kamihi Notes",
                body: "This is your native offline scratchpad for thoughts, outlines, and code snippets."
            )
            notes = [defaultNote]
            selectNote(defaultNote.id)
        } else {
            selectNote(notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first?.id)
        }
    }

    public var activeNote: Note? {
        notes.first(where: { $0.id == activeNoteID })
    }

    public var notesByRecency: [Note] {
        notes.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func matchingNotes(query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notesByRecency }
        return notesByRecency.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.body.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public func selectNote(_ id: UUID?) {
        activeNoteID = id
        text = notes.first(where: { $0.id == id })?.body ?? ""
    }

    public func createNewNote() {
        let note = Note()
        notes.append(note)
        selectNote(note.id)
    }

    public func deleteNote(id: UUID) {
        let wasActive = activeNoteID == id
        notes.removeAll(where: { $0.id == id })
        if wasActive {
            selectNote(notesByRecency.first?.id)
        }
    }

    public func updateTitle(id: UUID, title: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].title = title
        notes[index].updatedAt = Date()
    }

    public func updateBody(id: UUID, body: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        guard notes[index].body != body else { return }
        notes[index].body = body
        notes[index].updatedAt = Date()
        if activeNoteID == id { text = body }
    }

    /// Phone-keyboard bridge for the non-interactive external-display editor.
    /// The phone edits the active note body directly; no Mac-remote path is involved.
    public func appendToActiveBody(_ value: String) {
        guard !value.isEmpty,
              let id = activeNoteID,
              let note = notes.first(where: { $0.id == id }) else { return }
        updateBody(id: id, body: note.body + value)
    }

    public func deleteBackwardFromActiveBody() {
        guard let id = activeNoteID,
              var body = notes.first(where: { $0.id == id })?.body,
              !body.isEmpty else { return }
        body.removeLast()
        updateBody(id: id, body: body)
    }

    public func insertNewlineIntoActiveBody() {
        appendToActiveBody("\n")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = saved
        }
    }
}
