import SwiftUI

/// Native offline Notes app using Kamihi's persistent store. The layout follows
/// the desktop system language: edge-to-edge translucent sidebar, compact toolbar,
/// coloured app identity and a quiet content canvas.
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
                .frame(width: DesktopShellMetrics.sidebarWidth)

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesktopShellPalette.canvas)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold))
                    Text("On My iPhone")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.createNewNote() } label: {
                    DesktopToolbarIconLabel("square.and.pencil")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New note")
            }
            .padding(.horizontal, 10)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            if visibleNotes.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No Notes" : "No Results")
                        .font(.system(size: 12, weight: .semibold))
                    if !searchText.isEmpty {
                        Text("Try another search")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(visibleNotes) { note in noteRow(note) }
                    }
                    .padding(7)
                }
            }
        }
        .desktopSidebarSurface()
    }

    private func noteRow(_ note: DesktopNotesStore.Note) -> some View {
        let selected = note.id == store.activeNoteID
        return Button {
            store.activeNoteID = note.id
            store.text = note.body
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(for: note))
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(note.updatedAt, format: .dateTime.hour().minute())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(previewText(for: note))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                selected ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { store.deleteNote(id: note.id) } label: {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        TextField("Title", text: titleBinding(for: index))
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.45)
                            .foregroundStyle(.primary)

                        Text(store.notes[index].updatedAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Last edited \(store.notes[index].updatedAt.formatted(date: .long, time: .shortened))")

                        TextEditor(text: bodyBinding(for: index))
                            .font(.system(size: 15.5))
                            .foregroundStyle(.primary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 430)
                            .padding(.horizontal, -5)
                            .accessibilityLabel("Note body")
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 38)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(DesktopShellPalette.canvas)
            }
        } else {
            VStack(spacing: 9) {
                Image(systemName: "note.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Select a Note")
                    .font(.system(size: 15, weight: .semibold))
                Text("Choose a note in the sidebar or create a new one.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesktopShellPalette.canvas)
        }
    }

    private func editorToolbar(note: DesktopNotesStore.Note) -> some View {
        HStack(spacing: 6) {
            Text(displayTitle(for: note))
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Button { store.createNewNote() } label: {
                DesktopToolbarIconLabel("square.and.pencil")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New note")
            Button(role: .destructive) { store.deleteNote(id: note.id) } label: {
                DesktopToolbarIconLabel("trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
        .padding(.horizontal, 11)
        .frame(height: DesktopShellMetrics.toolbarHeight)
        .desktopAppToolbar()
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
