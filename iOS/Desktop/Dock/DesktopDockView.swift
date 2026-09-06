import SwiftUI

/// Floating macOS-inspired centered glass dock on the external display.
/// Uses vibrant macOS app tiles, glowing running-app indicator dots, and
/// software cursor hit-testing integration.
struct DesktopDockView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    var onOpenLauncher: () -> Void
    var onOpenWallpaperPicker: (() -> Void)? = nil

    private let pinnedApps: [(title: String, icon: String, color: Color)] = [
        ("Browser", "safari.fill", Color(red: 0.18, green: 0.55, blue: 0.95)),
        ("Documents", "doc.text.fill", Color(red: 0.28, green: 0.58, blue: 0.98)),
        ("Sheets", "tablecells.fill", Color(red: 0.20, green: 0.70, blue: 0.40)),
        ("Files", "folder.fill", Color(red: 0.40, green: 0.72, blue: 0.96)),
        ("Notes", "note.text", Color(red: 0.94, green: 0.76, blue: 0.20)),
        ("ChatGPT", "sparkles", Color(red: 0.16, green: 0.76, blue: 0.65)),
        ("YouTube", "play.rectangle.fill", Color(red: 0.96, green: 0.20, blue: 0.24)),
        ("Calculator", "plus.forwardslash.minus", Color.orange)
    ]

    private var pinnedTitles: Set<String> { Set(pinnedApps.map(\.title)) }
    private var increasedContrast: Bool { colorSchemeContrast == .increased }
    private var solidChrome: Bool { reduceTransparency || increasedContrast }

    private var unpinnedRunningTitles: [String] {
        var seen = Set<String>()
        return desktop.windows.compactMap { window in
            let title = window.title
            guard !pinnedTitles.contains(title), seen.insert(title).inserted else { return nil }
            return title
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // App Library / Launchpad Button
            Button(action: onOpenLauncher) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pink, Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        Color.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: DockGeometryPreferenceKey.self,
                        value: [DockItemGeometryPreference(target: .launcherToggle, frameInSurface: geo.frame(in: .named("desktopSurface")))]
                    )
                }
            )
            .accessibilityLabel("Open App Library")

            Divider().frame(height: 28).opacity(0.3)

            // Pinned Apps
            ForEach(pinnedApps, id: \.title) { app in
                dockAppTile(title: app.title, icon: app.icon, color: app.color)
            }

            // Running Unpinned Apps
            if !unpinnedRunningTitles.isEmpty {
                Divider().frame(height: 28).opacity(0.3)
                ForEach(unpinnedRunningTitles, id: \.self) { title in
                    dockAppTile(title: title, icon: symbolForRunningApp(title), color: .secondary)
                }
            }

            if let onOpenWallpaperPicker {
                Divider().frame(height: 28).opacity(0.3)

                Button(action: onOpenWallpaperPicker) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wallpaper Chooser")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(solidChrome ? 0.40 : 0.20), lineWidth: 0.8)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16),
            radius: 16,
            x: 0,
            y: 8
        )
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
        let isRunning = desktop.windows.contains(where: { $0.title == title })
        let isMinimized = desktop.windows.first(where: { $0.title == title })?.isMinimized ?? false
        let isActive = desktop.activeWindow?.title == title

        return Button {
            if isRunning, let window = desktop.windows.first(where: { $0.title == title }) {
                desktop.restoreAndActivate(window.id)
            } else {
                desktop.openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(
                        isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isActive ? Color.white.opacity(0.48) : Color.white.opacity(0.15),
                                lineWidth: isActive ? 1.2 : 0.6
                            )
                    }

                // Glowing indicator dot under running / minimized app (macOS parity)
                Circle()
                    .fill(isRunning ? (isMinimized ? Color(red: 1.00, green: 0.74, blue: 0.18) : (isActive ? Color.primary : Color.secondary.opacity(0.85))) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .opacity(isMinimized ? 0.78 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(target: .app(title: title), frameInSurface: geo.frame(in: .named("desktopSurface")))]
                )
            }
        )
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Active" : (isMinimized ? "Minimized" : (isRunning ? "Running" : "Not running")))
        .accessibilityHint("Opens or activates this app")
    }
}
