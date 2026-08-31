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

    @Published public var notes: [Note] = [] {
        didSet { save() }
    }

    @Published public var activeNoteID: UUID?
    @Published public var text: String = ""

    private let storageKey = "kamihi.desktop.notes.v2"

    private init() {
        load()
        if notes.isEmpty {
            let defaultNote = Note(
                title: "Welcome to Kamihi Notes",
                body: "This is your native offline scratchpad for thoughts, outlines, and code snippets."
            )
            notes.append(defaultNote)
            activeNoteID = defaultNote.id
            text = defaultNote.body
        } else {
            activeNoteID = notes.first?.id
            text = notes.first?.body ?? ""
        }
    }

    public var activeNote: Note? {
        get { notes.first(where: { $0.id == activeNoteID }) }
        set {
            guard let newValue, let idx = notes.firstIndex(where: { $0.id == newValue.id }) else { return }
            notes[idx] = newValue
        }
    }

    public func createNewNote() {
        let note = Note()
        notes.insert(note, at: 0)
        activeNoteID = note.id
    }

    public func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        if activeNoteID == id {
            activeNoteID = notes.first?.id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            self.notes = saved
        }
    }
}
