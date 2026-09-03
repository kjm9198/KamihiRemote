import SwiftUI

/// Native offline notes application for Kamihi Desktop.
///
/// The interaction model intentionally follows familiar iPad note-taking patterns
/// (sidebar, search, note list, editor and contextual actions) while using Kamihi's
/// own semantic styling rather than copying another app's proprietary trade dress.
struct DesktopNotesView: View {
    @StateObject private var store = DesktopNotesStore.shared
    @State private var searchText = ""

    private var visibleNotes: [DesktopNotesStore.Note] {
        let sorted = store.notes.sorted { $0.updatedAt > $1.updatedAt }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
                || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 238)

            Divider()

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes")
                        .font(.system(size: 20, weight: .bold))
                    Text("On My iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.createNewNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("New note")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Divider()

            if visibleNotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No Notes" : "No Results")
                        .font(.subheadline.weight(.semibold))
                    if !searchText.isEmpty {
                        Text("Try another search")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(visibleNotes) { note in
                            noteRow(note)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(.thinMaterial)
    }

    private func noteRow(_ note: DesktopNotesStore.Note) -> some View {
        let selected = note.id == store.activeNoteID
        return Button {
            store.activeNoteID = note.id
            store.text = note.body
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(displayTitle(for: note))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(note.updatedAt, format: .dateTime.hour().minute())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(previewText(for: note))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                selected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.deleteNote(id: note.id)
            } label: {
                Label("Delete Note", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(displayTitle(for: note)), \(previewText(for: note))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var editor: some View {
        if let activeID = store.activeNoteID,
           let index = store.notes.firstIndex(where: { $0.id == activeID }) {
            VStack(spacing: 0) {
                editorToolbar(note: store.notes[index])

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Title", text: titleBinding(for: index))
                            .textFieldStyle(.plain)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(store.notes[index].updatedAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Last edited \(store.notes[index].updatedAt.formatted(date: .long, time: .shortened))")

                        TextEditor(text: bodyBinding(for: index))
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 430)
                            .padding(.horizontal, -5)
                            .accessibilityLabel("Note body")
                    }
                    .frame(maxWidth: 700, alignment: .leading)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color(.systemBackground))
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Select a Note")
                    .font(.title3.weight(.semibold))
                Text("Choose a note from the sidebar or create a new one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }

    private func editorToolbar(note: DesktopNotesStore.Note) -> some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                store.createNewNote()
            } label: {
                Image(systemName: "square.and.pencil")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("New note")

            Button(role: .destructive) {
                store.deleteNote(id: note.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Delete note")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }

    private func titleBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { store.notes[index].title },
            set: { value in
                store.notes[index].title = value
                store.notes[index].updatedAt = Date()
            }
        )
    }

    private func bodyBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { store.notes[index].body },
            set: { value in
                store.notes[index].body = value
                store.notes[index].updatedAt = Date()
                store.text = value
            }
        )
    }

    private func displayTitle(for note: DesktopNotesStore.Note) -> String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Note" : trimmed
    }

    private func previewText(for note: DesktopNotesStore.Note) -> String {
        let flattened = note.body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.isEmpty ? "No additional text" : flattened
    }
}
