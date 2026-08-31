import SwiftUI

/// Native offline rich notes application on Kamihi Desktop.
struct DesktopNotesView: View {
    @StateObject private var store = DesktopNotesStore.shared

    var body: some View {
        HStack(spacing: 0) {
            // Note list sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Notes")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        store.createNewNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(red: 0.13, green: 0.14, blue: 0.19))

                Divider().background(Color.white.opacity(0.1))

                List {
                    ForEach(store.notes) { note in
                        Button {
                            store.activeNoteID = note.id
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(note.id == store.activeNoteID ? .white : .white.opacity(0.8))
                                    .lineLimit(1)

                                Text(note.body.isEmpty ? "No content" : note.body)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowBackground(
                            note.id == store.activeNoteID ? Color.cyan.opacity(0.2) : Color.clear
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(width: 140)
            .background(Color(red: 0.10, green: 0.11, blue: 0.15))

            Divider().background(Color.white.opacity(0.1))

            // Note editor
            if let activeID = store.activeNoteID,
               let index = store.notes.firstIndex(where: { $0.id == activeID }) {
                VStack(spacing: 0) {
                    TextField("Note Title", text: $store.notes[index].title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .textFieldStyle(.plain)

                    Divider().background(Color.white.opacity(0.08))

                    TextEditor(text: $store.notes[index].body)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                }
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Select or create a note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
            }
        }
    }
}
