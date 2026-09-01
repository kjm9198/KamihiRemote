import SwiftUI
import UIKit

/// Native offline notes application on Kamihi Desktop.
struct DesktopNotesView: View {
    @StateObject private var store = DesktopNotesStore.shared
    @State private var searchQuery = ""

    private var visibleNotes: [DesktopNotesStore.Note] {
        store.matchingNotes(query: searchQuery)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)

            Divider()

            editor
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kamihi Notes")
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)
                Spacer()
                Button {
                    store.createNewNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("New note")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search notes", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search notes")
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            Divider()

            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchQuery.isEmpty ? "No Notes" : "No Results",
                    systemImage: searchQuery.isEmpty ? "note.text" : "magnifyingglass",
                    description: Text(searchQuery.isEmpty ? "Create a note to get started." : "Try a different search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleNotes) { note in
                    Button {
                        store.selectNote(note.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : note.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No content" : note.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Text(note.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        note.id == store.activeNoteID
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteNote(id: note.id)
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    }
                    .accessibilityLabel(note.title.isEmpty ? "Untitled note" : note.title)
                    .accessibilityValue(note.id == store.activeNoteID ? "Selected" : "")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    @ViewBuilder
    private var editor: some View {
        if let note = store.activeNote {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("Note Title", text: titleBinding(for: note.id))
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Note title")

                    Text(note.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        store.deleteNote(id: note.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete current note")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Divider()

                TextEditor(text: bodyBinding(for: note.id))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .accessibilityLabel("Note body")
            }
            .background(Color(uiColor: .systemBackground))
        } else {
            ContentUnavailableView(
                "Select or Create a Note",
                systemImage: "note.text",
                description: Text("Notes stay on this iPhone and are available when Kamihi Desktop reconnects.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func titleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { store.notes.first(where: { $0.id == id })?.title ?? "" },
            set: { store.updateTitle(id: id, title: $0) }
        )
    }

    private func bodyBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { store.notes.first(where: { $0.id == id })?.body ?? "" },
            set: { store.updateBody(id: id, body: $0) }
        )
    }
}
