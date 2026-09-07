import SwiftUI

/// Floating macOS-inspired glass Dock shared by Desktop Lab and the physical
/// external display. App hit regions are still published into
/// DesktopDockHitRegistry so the iPhone trackpad can operate the non-interactive
/// display precisely, including pointer-driven icon magnification.
struct DesktopDockView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var hitRegistry = DesktopDockHitRegistry.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onOpenLauncher: () -> Void
    var onOpenWallpaperPicker: (() -> Void)? = nil

    /// Keep Kamihi-owned apps visually distinct from Apple or third-party apps.
    /// In particular, Kamihi Browser must never present Safari's compass glyph.
    /// Third-party web apps use recognizable platform-neutral symbols here until
    /// approved local brand assets are bundled; never synthesize/lookalike logos.
    private let pinnedApps: [(title: String, icon: String, color: Color)] = [
        ("Browser", "globe.americas.fill", .blue),
        ("Documents", "doc.text.fill", .blue),
        ("Sheets", "tablecells.fill", .green),
        ("Files", "folder.fill", .blue),
        ("Notes", "note.text", .yellow),
        ("Photos", "photo.on.rectangle.angled", .purple),
        ("ChatGPT", "bubble.left.and.bubble.right.fill", .mint),
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
        HStack(alignment: .bottom, spacing: 7) {
            launcherButton
            dockDivider

            ForEach(pinnedApps, id: \.title) { app in
                dockAppTile(title: app.title, icon: app.icon, color: app.color)
            }

            if !unpinnedRunningTitles.isEmpty {
                dockDivider
                ForEach(unpinnedRunningTitles, id: \.self) { title in
                    dockAppTile(title: title, icon: symbolForRunningApp(title), color: .secondary)
                }
            }

            if let onOpenWallpaperPicker {
                dockDivider
                Button(action: onOpenWallpaperPicker) {
                    VStack(spacing: 4) {
                        dockIcon(
                            symbol: "paintpalette.fill",
                            color: .cyan,
                            selected: false,
                            hovered: hitRegistry.hoveredDockTitle == "Wallpaper"
                        )
                        Color.clear.frame(width: 4.5, height: 4.5)
                    }
                }
                .buttonStyle(.plain)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DockGeometryPreferenceKey.self,
                            value: [DockItemGeometryPreference(
                                target: .wallpaperToggle,
                                frameInSurface: geo.frame(in: .named("desktopSurface"))
                            )]
                        )
                    }
                )
                .accessibilityLabel("Wallpaper Chooser")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .desktopGlassSurface(cornerRadius: 18)
    }

    private var dockDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 0.7, height: 36)
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
    }

    private var launcherButton: some View {
        Button(action: onOpenLauncher) {
            VStack(spacing: 4) {
                dockIcon(
                    symbol: "circle.grid.3x3.fill",
                    color: .purple,
                    selected: hitRegistry.isLauncherOpen,
                    hovered: hitRegistry.isLauncherToggleHovered
                )
                Color.clear.frame(width: 4.5, height: 4.5)
            }
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
        .accessibilityLabel("Open Applications")
    }

    @ViewBuilder
    private func dockIcon(symbol: String, color: Color, selected: Bool, hovered: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.96), color.opacity(0.66)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(selected ? 0.48 : 0.22), lineWidth: selected ? 1.0 : 0.7)
                }
                .shadow(color: Color.black.opacity(hovered ? 0.30 : 0.18), radius: hovered ? 9 : 5, y: hovered ? 6 : 3)

            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.14), radius: 1, y: 1)
        }
        .frame(width: 48, height: 48)
        .scaleEffect(reduceMotion ? 1 : (hovered ? 1.18 : (selected ? 1.04 : 1.0)))
        .offset(y: reduceMotion ? 0 : (hovered ? -7 : 0))
        .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: hovered)
        .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: selected)
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
        if normalized.contains("chatgpt") { return "bubble.left.and.bubble.right.fill" }
        if normalized.contains("youtube") { return "play.rectangle.fill" }
        if normalized.contains("browser") || normalized.contains("web") { return "globe.americas.fill" }
        return "app.fill"
    }

    private func dockAppTile(title: String, icon: String, color: Color) -> some View {
        let window = desktop.windows.first(where: { $0.title == title })
        let isRunning = window != nil
        let isMinimized = window?.isMinimized ?? false
        let isActive = desktop.activeWindow?.title == title
        let isHovered = hitRegistry.hoveredDockTitle == title

        return Button {
            if let window {
                desktop.restoreAndActivate(window.id)
            } else {
                desktop.openProductivityApp(title, frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60))
            }
        } label: {
            VStack(spacing: 4) {
                dockIcon(symbol: icon, color: color, selected: isActive, hovered: isHovered)

                Circle()
                    .fill(
                        isRunning
                            ? (isMinimized ? Color.orange : Color.primary.opacity(isActive ? 0.90 : 0.62))
                            : Color.clear
                    )
                    .frame(width: 4.5, height: 4.5)
            }
            .opacity(isMinimized ? 0.78 : 1)
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
