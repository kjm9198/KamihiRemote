import SwiftUI

/// Mission Control / Window Overview for rapid spatial window switching.
struct DesktopWindowOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: KamihiTheme.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    if desktop.windows.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No Open Windows")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Open apps from the Launcher to get started.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: KamihiTheme.Spacing.md) {
                            ForEach(desktop.windows) { window in
                                windowCard(window)
                            }
                        }
                        .padding(KamihiTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle("Window Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Tile All") {
                        desktop.openVibeWorkspace()
                        dismiss()
                    }
                }
            }
        }
    }

    private func windowCard(_ window: DesktopSession.DesktopWindow) -> some View {
        Button {
            desktop.restoreAndActivate(window.id)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: appIcon(for: window.title))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text(window.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    if window.isMinimized {
                        Text("Minimized")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15), in: Capsule())
                    }
                }

                // Window preview placeholder shape
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 80)
                    .overlay(
                        Text(window.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    )

                HStack {
                    Button {
                        desktop.close(window.id)
                    } label: {
                        Text("Close")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        desktop.toggleMaximize(window.id)
                    } label: {
                        Text(window.isMaximized ? "Restore" : "Maximize")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.14, blue: 0.19))
            .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                    .strokeBorder(desktop.activeWindowID == window.id ? Color.cyan.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func appIcon(for title: String) -> String {
        switch title {
        case "Browser": return "globe"
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Notes": return "note.text"
        case "Files": return "folder.fill"
        default: return "app.window.checkmark"
        }
    }
}
