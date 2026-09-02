import SwiftUI

/// Mission Control / Window Overview for rapid spatial window switching.
///
/// This surface intentionally operates only on the windows that are already open.
/// It must never launch a Vibe workspace (or any other profile) as a side effect of
/// generic window management.
struct DesktopWindowOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        VStack(alignment: .leading, spacing: KamihiTheme.Spacing.md) {
                            spatialDesktopMap

                            LazyVGrid(columns: columns, spacing: KamihiTheme.Spacing.md) {
                                ForEach(desktop.windows) { window in
                                    windowCard(window)
                                }
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

    /// A single whole-desktop map keeps the user's spatial memory intact when
    /// switching windows. Unlike live thumbnails it only renders geometry and
    /// labels, so the overview does not wake WebViews or media just to preview them.
    private var spatialDesktopMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Desktop Map")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("Tap a window to return")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.045))

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: max(4, geo.size.height * 0.045))
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: max(7, geo.size.height * 0.115))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)

                    ForEach(Array(desktop.windows.enumerated()), id: \.element.id) { index, window in
                        spatialWindowButton(window, in: geo.size)
                            .zIndex(desktop.activeWindowID == window.id ? 100 : Double(index))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
            }
            .frame(height: 150)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spatial desktop map")
            .accessibilityHint("Contains all open windows positioned like the external desktop")
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
    }

    private func spatialWindowButton(
        _ window: DesktopSession.DesktopWindow,
        in canvasSize: CGSize
    ) -> some View {
        let desktopFrame = desktop.effectiveFrame(for: window)
        let width = max(52, desktopFrame.width * canvasSize.width)
        let height = max(34, desktopFrame.height * canvasSize.height)
        let x = min(max(desktopFrame.midX * canvasSize.width, width / 2), canvasSize.width - width / 2)
        let y = min(max(desktopFrame.midY * canvasSize.height, height / 2), canvasSize.height - height / 2)
        let isActive = desktop.activeWindowID == window.id

        return Button {
            activateFromOverview(window.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(window.isMinimized ? 0.18 : 0.44)
                            : Color.white.opacity(window.isMinimized ? 0.08 : 0.18)
                    )

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.30),
                        style: StrokeStyle(
                            lineWidth: isActive ? 2 : 1,
                            dash: window.isMinimized ? [5, 4] : []
                        )
                    )

                HStack(spacing: 4) {
                    Image(systemName: appIcon(for: window.title))
                        .font(.system(size: 9, weight: .semibold))
                    Text(window.title)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.78))
                .padding(.horizontal, 5)
            }
            .frame(width: width, height: height)
            .opacity(window.isMinimized ? 0.52 : 1)
            .shadow(color: .black.opacity(isActive ? 0.24 : 0.10), radius: isActive ? 8 : 3, y: 2)
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: desktopFrame)
        .accessibilityLabel("\(window.title), \(windowStateDescription(window))")
        .accessibilityHint("Activates this window and closes Window Overview")
    }

    private func windowCard(_ window: DesktopSession.DesktopWindow) -> some View {
        Button {
            activateFromOverview(window.id)
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

    private func activateFromOverview(_ id: UUID) {
        desktop.restoreAndActivate(id)
        dismiss()
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
