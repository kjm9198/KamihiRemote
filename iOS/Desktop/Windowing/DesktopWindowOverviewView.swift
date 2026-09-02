import SwiftUI

/// Mission Control / Window Overview for rapid spatial window switching.
///
/// This surface intentionally operates only on the windows that are already open.
/// It must never launch a Vibe workspace (or any other profile) as a side effect of
/// generic window management.
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
                    Button("Restore All") {
                        restoreAllOpenWindows()
                    }
                    .disabled(!desktop.windows.contains(where: { $0.isMinimized }))
                    .accessibilityHint("Restores minimized windows without changing your apps or workspace")
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
                        .foregroundStyle(Color.accentColor)
                    Text(window.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    stateBadge(for: window)
                }

                spatialPreview(for: window)
                    .frame(height: 86)

                HStack {
                    Button {
                        desktop.close(window.id)
                    } label: {
                        Text("Close")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close \(window.title)")

                    Spacer()

                    Button {
                        desktop.toggleMaximize(window.id)
                    } label: {
                        Text(window.isMaximized ? "Restore" : "Maximize")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(window.isMaximized ? "Restore \(window.title)" : "Maximize \(window.title)")
                }
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.14, blue: 0.19))
            .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        desktop.activeWindowID == window.id ? Color.accentColor.opacity(0.78) : Color.white.opacity(0.1),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(window.title), \(windowStateDescription(window))")
        .accessibilityHint("Activates this window and closes Window Overview")
    }

    /// Lightweight spatial mini-map. It renders geometry only—never live WebKit or
    /// media—so Window Overview stays cheap while still communicating where the
    /// window actually sits on the external desktop canvas.
    private func spatialPreview(for window: DesktopSession.DesktopWindow) -> some View {
        GeometryReader { geo in
            let desktopFrame = desktop.effectiveFrame(for: window)
            let width = max(18, desktopFrame.width * geo.size.width)
            let height = max(14, desktopFrame.height * geo.size.height)
            let x = min(max(desktopFrame.midX * geo.size.width, width / 2), geo.size.width - width / 2)
            let y = min(max(desktopFrame.midY * geo.size.height, height / 2), geo.size.height - height / 2)

            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.045))

                // Safe desktop canvas guide: status area at the top and dock area
                // at the bottom remain subtly visible in the miniature.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: max(3, geo.size.height * 0.045))
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: max(5, geo.size.height * 0.115))
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        desktop.activeWindowID == window.id
                            ? Color.accentColor.opacity(window.isMinimized ? 0.16 : 0.42)
                            : Color.white.opacity(window.isMinimized ? 0.08 : 0.20)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                desktop.activeWindowID == window.id
                                    ? Color.accentColor.opacity(0.88)
                                    : Color.white.opacity(0.28),
                                lineWidth: 1
                            )
                    }
                    .frame(width: width, height: height)
                    .position(x: x, y: y)
                    .opacity(window.isMinimized ? 0.45 : 1)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stateBadge(for window: DesktopSession.DesktopWindow) -> some View {
        if window.isMinimized {
            Text("Minimized")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15), in: Capsule())
        } else if window.isMaximized {
            Text("Full")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
        } else if desktop.activeWindowID == window.id {
            Text("Active")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
        }
    }

    private func restoreAllOpenWindows() {
        let ids = desktop.windows.filter(\.isMinimized).map(\.id)
        for id in ids {
            desktop.restoreAndActivate(id)
        }
    }

    private func windowStateDescription(_ window: DesktopSession.DesktopWindow) -> String {
        if window.isMinimized { return "minimized" }
        if window.isMaximized { return "maximized" }
        if desktop.activeWindowID == window.id { return "active" }
        return "open"
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
