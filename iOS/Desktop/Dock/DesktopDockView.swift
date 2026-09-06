import SwiftUI

/// Floating glass dock shared by Desktop Lab and the physical external display.
/// App hit regions are still published into DesktopDockHitRegistry so the iPhone
/// trackpad can operate the non-interactive display precisely.
struct DesktopDockView: View {
    @EnvironmentObject private var desktop: DesktopSession
    var onOpenLauncher: () -> Void
    var onOpenWallpaperPicker: (() -> Void)? = nil

    private let pinnedApps: [(title: String, icon: String, color: Color)] = [
        ("Browser", "safari.fill", .blue),
        ("Documents", "doc.text.fill", .blue),
        ("Sheets", "tablecells.fill", .green),
        ("Files", "folder.fill", .blue),
        ("Notes", "note.text", .yellow),
        ("ChatGPT", "sparkles", .mint),
        ("YouTube", "play.rectangle.fill", .red),
        ("Settings", "gearshape.fill", .gray)
    ]

    private var pinnedTitles: Set<String> { Set(pinnedApps.map(\.title)) }

    private var unpinnedRunningTitles: [String] {
        var seen = Set<String>()
        return desktop.windows.compactMap { window in
            let title = window.title
            guard !pinnedTitles.contains(title), seen.insert(title).inserted else { return nil }
            return title
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            launcherButton
            Divider().frame(height: 28).opacity(0.24)

            ForEach(pinnedApps, id: \.title) { app in
                dockAppTile(title: app.title, icon: app.icon, color: app.color)
            }

            if !unpinnedRunningTitles.isEmpty {
                Divider().frame(height: 28).opacity(0.24)
                ForEach(unpinnedRunningTitles, id: \.self) { title in
                    dockAppTile(title: title, icon: symbolForRunningApp(title), color: .secondary)
                }
            }

            if let onOpenWallpaperPicker {
                Divider().frame(height: 28).opacity(0.24)
                Button(action: onOpenWallpaperPicker) {
                    dockIcon(symbol: "paintpalette.fill", color: .cyan, selected: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wallpaper Chooser")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .desktopGlassSurface(cornerRadius: 22)
    }

    private var launcherButton: some View {
        Button(action: onOpenLauncher) {
            dockIcon(symbol: "circle.grid.3x3.fill", color: .purple, selected: false)
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .launcherToggle,
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
        .accessibilityLabel("Open App Library")
    }

    @ViewBuilder
    private func dockIcon(symbol: String, color: Color, selected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(
                selected ? Color.white.opacity(0.20) : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(selected ? 0.34 : 0.10), lineWidth: 0.7)
            }
    }

    private func symbolForRunningApp(_ title: String) -> String {
        let normalized = title.lowercased()
        if normalized.contains("setting") { return "gearshape.fill" }
        if normalized.contains("calculator") { return "plus.forwardslash.minus" }
        if normalized.contains("photo") { return "photo.on.rectangle.angled" }
        if normalized.contains("document") { return "doc.text.fill" }
        if normalized.contains("sheet") { return "tablecells.fill" }
        if normalized.contains("pdf") { return "doc.richtext.fill" }
        if normalized.contains("clipboard") { return "doc.on.clipboard.fill" }
        if normalized.contains("browser") || normalized.contains("web") { return "safari.fill" }
        return "app.fill"
    }

    private func dockAppTile(title: String, icon: String, color: Color) -> some View {
        let window = desktop.windows.first(where: { $0.title == title })
        let isRunning = window != nil
        let isMinimized = window?.isMinimized ?? false
        let isActive = desktop.activeWindow?.title == title

        return Button {
            if let window {
                desktop.restoreAndActivate(window.id)
            } else {
                desktop.openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
            }
        } label: {
            VStack(spacing: 3) {
                dockIcon(symbol: icon, color: color, selected: isActive)

                Circle()
                    .fill(
                        isRunning
                            ? (isMinimized ? Color.orange : (isActive ? Color.primary : Color.secondary.opacity(0.82)))
                            : Color.clear
                    )
                    .frame(width: 4, height: 4)
            }
            .opacity(isMinimized ? 0.72 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .app(title: title),
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Active" : (isMinimized ? "Minimized" : (isRunning ? "Running" : "Not running")))
        .accessibilityHint("Opens or activates this app")
    }
}
