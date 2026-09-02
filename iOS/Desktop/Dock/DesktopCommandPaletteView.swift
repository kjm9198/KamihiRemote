import SwiftUI

/// Cmd+K searchable command palette for rapid actions, window snapping, and app launching.
struct DesktopCommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    @State private var query = ""
    @State private var showInputGuide = false

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
                                    .accessibilityHidden(true)

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
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Runs this desktop command")
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInputGuide = true
                    } label: {
                        Image(systemName: "keyboard.badge.ellipsis")
                    }
                    .accessibilityLabel("Keyboard and gesture guide")
                    .accessibilityHint("Shows the available phone gestures and hardware keyboard controls for Kamihi Desktop")
                }
            }
            .sheet(isPresented: $showInputGuide) {
                DesktopInputGuideView()
            }
        }
    }
}

/// Discoverable, VoiceOver-friendly reference for the normal Kamihi Desktop input model.
/// Keep this limited to controls that are actually available in the Desktop-first flow.
private struct DesktopInputGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private struct GuideItem: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let trackpadItems = [
        GuideItem(symbol: "hand.point.up.left", title: "One finger", detail: "Move the pointer. Drag a title bar to move a window."),
        GuideItem(symbol: "hand.draw", title: "Two fingers", detail: "Scroll horizontally or vertically. Drag on a window edge to resize."),
        GuideItem(symbol: "cursorarrow.click.2", title: "Two-finger tap", detail: "Open the context menu for the item under the pointer."),
        GuideItem(symbol: "rectangle.stack", title: "Three fingers up", detail: "Open Window Overview."),
        GuideItem(symbol: "arrow.left.and.right", title: "Three fingers left or right", detail: "Cycle backward or forward through open desktop windows.")
    ]

    private let phoneItems = [
        GuideItem(symbol: "square.grid.2x2", title: "Desktop preview", detail: "Double-tap the preview to open the App Library."),
        GuideItem(symbol: "keyboard", title: "Keyboard", detail: "Use the Keyboard control to type into the active supported desktop app."),
        GuideItem(symbol: "scope", title: "Precision Mode", detail: "Reduce pointer speed when selecting small desktop targets."),
        GuideItem(symbol: "iphone.and.arrow.forward", title: "Continue on iPhone", detail: "Use touch on the phone for authentication, CAPTCHA, file picking, and other iOS-owned flows.")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(trackpadItems) { item in
                        guideRow(item)
                    }
                } header: {
                    Text("Trackpad gestures")
                } footer: {
                    Text("Gesture actions operate only inside Kamihi Desktop. They do not take over iOS system input.")
                }

                Section("Phone controls") {
                    ForEach(phoneItems) { item in
                        guideRow(item)
                    }
                }

                Section {
                    Label("Open the Command Palette to search available app, window, and workspace actions.", systemImage: "command")
                        .font(.body)
                        .accessibilityElement(children: .combine)
                } header: {
                    Text("Hardware keyboard")
                } footer: {
                    Text("Kamihi uses public iOS keyboard routing. System-reserved shortcuts remain owned by iOS.")
                }
            }
            .navigationTitle("Keyboard & Gestures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func guideRow(_ item: GuideItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.title3)
                .frame(width: 30)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
