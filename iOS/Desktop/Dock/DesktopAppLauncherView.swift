import SwiftUI

/// macOS-inspired Applications chooser for Kamihi Desktop. Direct touch
/// (Desktop Lab / iPhone sheets) opens with one tap; the non-interactive external
/// display still uses the software-cursor hit registry and deliberate desktop
/// click semantics.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var hitRegistry = DesktopDockHitRegistry.shared
    @StateObject private var browser = DesktopBrowserState.shared
    @State private var searchText = ""

    private struct AppItem: Identifiable {
        let id: String
        let title: String
        let icon: String
        let color: Color
        let category: String
        let url: URL?

        init(id: String? = nil, title: String, icon: String, color: Color, category: String, url: URL? = nil) {
            self.id = id ?? title
            self.title = title
            self.icon = icon
            self.color = color
            self.category = category
            self.url = url
        }
    }

    private let apps: [AppItem] = [
        AppItem(title: "Browser", icon: "safari.fill", color: .blue, category: "Web"),
        AppItem(title: "Documents", icon: "doc.text.fill", color: .blue, category: "Productivity"),
        AppItem(title: "Sheets", icon: "tablecells.fill", color: .green, category: "Productivity"),
        AppItem(title: "Notes", icon: "note.text", color: .yellow, category: "Productivity"),
        AppItem(title: "Files", icon: "folder.fill", color: .blue, category: "Utilities"),
        AppItem(title: "ChatGPT", icon: "sparkles", color: .mint, category: "AI & Productivity"),
        AppItem(title: "YouTube", icon: "play.rectangle.fill", color: .red, category: "Media"),
        AppItem(title: "Photos", icon: "photo.on.rectangle.angled", color: .purple, category: "Media"),
        AppItem(title: "Calculator", icon: "plus.forwardslash.minus", color: .orange, category: "Utilities"),
        AppItem(title: "Clipboard", icon: "doc.on.clipboard.fill", color: .indigo, category: "Utilities"),
        AppItem(title: "PDF Viewer", icon: "doc.richtext.fill", color: .red, category: "Documents"),
        AppItem(title: "Settings", icon: "gearshape.fill", color: .gray, category: "System"),
        AppItem(title: "Display Diagnostics", icon: "waveform.path.ecg.rectangle", color: .teal, category: "System")
    ]

    private var pinnedWebApps: [AppItem] {
        browser.bookmarks.prefix(12).map { bookmark in
            let fallback = bookmark.url.host?.replacingOccurrences(of: "www.", with: "") ?? "Website"
            let title = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return AppItem(
                id: "pinned-web-\(bookmark.id.uuidString)",
                title: title.isEmpty ? fallback : title,
                icon: "bookmark.fill",
                color: .accentColor,
                category: "Pinned Website",
                url: bookmark.url
            )
        }
    }

    private var filteredApps: [AppItem] {
        let all = apps + pinnedWebApps
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.category.localizedCaseInsensitiveContains(searchText)
            || ($0.url?.host?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(minimum: 92, maximum: 124), spacing: 22), count: 6)

    var body: some View {
        ZStack {
            // The parent supplies the full glass surface. This subtle overlay gives
            // the chooser the soft depth of macOS Launchpad without double-blurring.
            LinearGradient(
                colors: [Color.white.opacity(0.055), Color.clear, Color.black.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                header

                if filteredApps.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(filteredApps) { app in
                                appTile(app)
                            }
                        }
                        .padding(.horizontal, 34)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .launcherContainer,
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Applications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.90))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 350, height: 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No applications found")
                .font(.system(size: 15, weight: .semibold))
            Text("Try another app, category, or website name.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Button("Clear Search") { searchText = "" }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func appTile(_ app: AppItem) -> some View {
        let isHovered = hitRegistry.hoveredAppTitle == app.title
        let isSelected = hitRegistry.selectedLauncherTitle == app.title
        let highlighted = isHovered || isSelected
        let running = desktop.windows.contains { $0.title == app.title }

        return Button {
            launchApp(app)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [app.color.opacity(0.98), app.color.opacity(0.66)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                        }
                        .shadow(color: Color.black.opacity(highlighted ? 0.28 : 0.18), radius: highlighted ? 10 : 6, y: highlighted ? 6 : 4)

                    Image(systemName: app.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.16), radius: 1, y: 1)
                }
                .frame(width: 70, height: 70)
                .scaleEffect(highlighted ? 1.08 : 1)
                .offset(y: highlighted ? -4 : 0)
                .animation(KamihiTheme.Animation.fast, value: highlighted)

                Text(app.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Circle()
                    .fill(running ? Color.primary.opacity(0.72) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .launcherApp(title: app.title, url: app.url),
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
        .accessibilityLabel(app.title)
        .accessibilityHint("Open \(app.title)")
    }

    private func launchApp(_ app: AppItem) {
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        let frame = CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)

        if let url = app.url {
            browser.newTab(url: url)
            if let existing = desktop.windows.first(where: { $0.title == "Browser" }) {
                desktop.restoreAndActivate(existing.id)
            } else {
                desktop.openProductivityApp("Browser", frame: frame)
            }
        } else if let existing = desktop.windows.first(where: { $0.title == app.title }) {
            desktop.restoreAndActivate(existing.id)
        } else {
            desktop.openProductivityApp(app.title, frame: frame)
        }
        closeLauncher()
    }

    private func closeLauncher() {
        hitRegistry.isLauncherOpen = false
        hitRegistry.onDismissLauncher?()
        dismiss()
    }
}
