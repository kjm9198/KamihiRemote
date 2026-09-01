import SwiftUI

/// Cmd+K searchable command palette for rapid actions, window snapping, and app launching.
struct DesktopCommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    @State private var query = ""

    private struct CommandItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let category: String
        let action: (DesktopSession) -> Void
    }

    private let centeredAppFrame = CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)

    private var allCommands: [CommandItem] {
        [
            // Apps — all normal launches use the same centered 60% geometry.
            CommandItem(title: "Open ChatGPT", icon: "sparkles", category: "Apps") { _ = $0.openProductivityApp("ChatGPT", frame: centeredAppFrame) },
            CommandItem(title: "Open Browser", icon: "globe", category: "Apps") { $0.openBrowser() },
            CommandItem(title: "Open YouTube", icon: "play.rectangle.fill", category: "Apps") { _ = $0.openProductivityApp("YouTube", frame: centeredAppFrame) },
            CommandItem(title: "Open Notes", icon: "note.text", category: "Apps") { _ = $0.openProductivityApp("Notes", frame: centeredAppFrame) },
            CommandItem(title: "Open Files", icon: "folder.fill", category: "Apps") { _ = $0.openProductivityApp("Files", frame: centeredAppFrame) },

            // Window Management
            CommandItem(title: "Snap Left (Half)", icon: "rectangle.leadinghalf.filled", category: "Window") { $0.snapActiveLeft() },
            CommandItem(title: "Snap Right (Half)", icon: "rectangle.trailinghalf.filled", category: "Window") { $0.snapActiveRight() },
            CommandItem(title: "Maximize Active Window", icon: "arrow.up.left.and.arrow.down.right", category: "Window") {
                if let id = $0.activeWindowID { $0.toggleMaximize(id) }
            },
            CommandItem(title: "Minimize Active Window", icon: "minus", category: "Window") {
                if let id = $0.activeWindowID { $0.minimize(id) }
            },
            CommandItem(title: "Close Active Window", icon: "xmark", category: "Window") {
                if let id = $0.activeWindowID { $0.close(id) }
            },

            // Workspaces — Vibe remains explicitly user-triggered only.
            CommandItem(title: "Start Vibe Workspace (Tiled)", icon: "sparkles.rectangle.stack", category: "Workspaces") { $0.openVibeWorkspace() },
            CommandItem(title: "Close All Windows", icon: "trash", category: "Workspaces") { $0.closeAllDesktopWindows() }
        ]
    }

    private var filteredCommands: [CommandItem] {
        if query.isEmpty { return allCommands }
        return allCommands.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()

                List {
                    ForEach(filteredCommands) { command in
                        Button {
                            command.action(desktop)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.cyan)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.title)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(command.category)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }

                                Spacer()

                                Image(systemName: "arrow.turn.down.left")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(red: 0.12, green: 0.14, blue: 0.19))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $query, prompt: "Type a command or action...")
            .navigationTitle("Command Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
