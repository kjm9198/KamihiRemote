import SwiftUI

/// App Library for Kamihi Desktop. Direct touch (Desktop Lab / iPhone sheets)
/// opens with one tap; the non-interactive external display still uses the
/// software-cursor hit registry and its deliberate desktop click semantics.
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
        AppItem(title: "Documents", icon: "doc.richtext.fill", color: .blue, category: "Productivity"),
        AppItem(title: "Sheets", icon: "tablecells.fill", color: .green, category: "Productivity"),
        AppItem(title: "Notes", icon: "note.text", color: .yellow, category: "Productivity"),
        AppItem(title: "Files", icon: "folder.fill", color: .blue, category: "Utilities"),
        AppItem(title: "ChatGPT", icon: "sparkles", color: .mint, category: "AI & Productivity"),
        AppItem(title: "YouTube", icon: "play.rectangle.fill", color: .red, category: "Media"),
        AppItem(title: "Photos", icon: "photo.stack.fill", color: .purple, category: "Media"),
        AppItem(title: "Calculator", icon: "plus.forwardslash.minus", color: .orange, category: "Utilities"),
        AppItem(title: "Clipboard", icon: "doc.on.clipboard.fill", color: .indigo, category: "Utilities"),
        AppItem(title: "PDF Viewer", icon: "doc.text.fill", color: .red, category: "Documents"),
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

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 132), spacing: 18)]

    var body: some View {
        VStack(spacing: 14) {
            header

            if filteredApps.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(filteredApps) { app in appTile(app) }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .desktopGlassSurface(cornerRadius: 24)
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
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps & websites", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: 390, minHeight: 38)
            .desktopGlassSurface(cornerRadius: 12, elevated: false)

            Spacer()

            Text("Apps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: closeLauncher) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .desktopGlassSurface(cornerRadius: 17, elevated: false)
            .accessibilityLabel("Close App Library")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No apps found").font(.headline)
            Text("Try another app name, category or website.")
                .font(.subheadline)
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
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(app.color.opacity(highlighted ? 0.24 : 0.13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(highlighted ? 0.44 : 0.16), lineWidth: highlighted ? 1.2 : 0.7)
                        }

                    Image(systemName: app.icon)
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(app.color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if running {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                            .padding(6)
                    }
                }
                .frame(width: 68, height: 68)
                .scaleEffect(highlighted ? 1.06 : 1)
                .animation(KamihiTheme.Animation.fast, value: highlighted)

                Text(app.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(app.category)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
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
