import SwiftUI

/// Launchpad / App Library grid for opening applications on Kamihi Desktop.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var hitRegistry = DesktopDockHitRegistry.shared
    @StateObject private var browser = DesktopBrowserState.shared
    @State private var searchText = ""
    @State private var lastTapId: String? = nil
    @State private var lastTapTime: TimeInterval = 0

    private struct AppItem: Identifiable {
        let id: String
        let title: String
        let icon: String
        let color: Color
        let category: String
        let url: URL?

        init(
            id: String? = nil,
            title: String,
            icon: String,
            color: Color,
            category: String,
            url: URL? = nil
        ) {
            self.id = id ?? title
            self.title = title
            self.icon = icon
            self.color = color
            self.category = category
            self.url = url
        }
    }

    private let apps: [AppItem] = [
        AppItem(title: "Browser", icon: "globe", color: Color(red: 0.22, green: 0.58, blue: 0.94), category: "Web"),
        AppItem(title: "Documents", icon: "doc.richtext.fill", color: Color(red: 0.26, green: 0.52, blue: 0.92), category: "Productivity"),
        AppItem(title: "Sheets", icon: "tablecells.fill", color: Color(red: 0.20, green: 0.66, blue: 0.38), category: "Productivity"),
        AppItem(title: "Notes", icon: "note.text", color: Color(red: 0.92, green: 0.74, blue: 0.24), category: "Productivity"),
        AppItem(title: "Files", icon: "folder.fill", color: Color(red: 0.42, green: 0.68, blue: 0.94), category: "Utilities"),
        AppItem(title: "ChatGPT", icon: "sparkles", color: Color(red: 0.18, green: 0.72, blue: 0.62), category: "AI & Productivity"),
        AppItem(title: "YouTube", icon: "play.rectangle.fill", color: Color(red: 0.94, green: 0.22, blue: 0.28), category: "Media"),
        AppItem(title: "PDF Viewer", icon: "doc.text.fill", color: Color.red, category: "Documents"),
        AppItem(title: "Calculator", icon: "plus.slash.minus", color: Color.orange, category: "Utilities"),
        AppItem(title: "Clipboard", icon: "doc.on.clipboard.fill", color: Color.indigo, category: "Utilities"),
        AppItem(title: "Photos", icon: "photo.stack.fill", color: Color.purple, category: "Media"),
        AppItem(title: "Display Diagnostics", icon: "waveform.path.ecg.rectangle", color: Color.teal, category: "System")
    ]

    private var pinnedWebApps: [AppItem] {
        browser.bookmarks.prefix(12).map { bookmark in
            let fallbackTitle = bookmark.url.host?.replacingOccurrences(of: "www.", with: "") ?? "Website"
            let trimmedTitle = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return AppItem(
                id: "pinned-web-\(bookmark.id.uuidString)",
                title: trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle,
                icon: "app.badge",
                color: Color.accentColor,
                category: "Pinned Web App",
                url: bookmark.url
            )
        }
    }

    private var allApps: [AppItem] {
        apps + pinnedWebApps
    }

    private var filteredApps: [AppItem] {
        if searchText.isEmpty { return allApps }
        return allApps.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            ($0.url?.host?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 130), spacing: 18)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // macOS Launchpad Search Bar Header
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Search Apps & Websites", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                }
                .frame(maxWidth: 380)

                Spacer()

                Text("Double-tap app to open")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.05), in: Capsule())

                Button {
                    closeLauncher()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Launchpad")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // App Grid
            if filteredApps.isEmpty {
                emptySearchState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredApps) { app in
                            appTile(app)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
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

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No Apps Found")
                .font(.headline)

            Text("Try another app name or keyword.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Clear Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func appTile(_ app: AppItem) -> some View {
        let isHovered = hitRegistry.hoveredAppTitle == app.title
        let isSelected = hitRegistry.selectedLauncherTitle == app.title
        let isHighlighted = isHovered || isSelected

        return Button {
            handleAppTap(app)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    app.color.opacity(isHighlighted ? 0.35 : 0.18),
                                    app.color.opacity(isHighlighted ? 0.20 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isHighlighted ? Color.white.opacity(0.65) : Color.white.opacity(0.20),
                                    lineWidth: isHighlighted ? 1.5 : 0.8
                                )
                        }
                        .shadow(
                            color: isHighlighted ? app.color.opacity(0.40) : Color.clear,
                            radius: isHighlighted ? 14 : 0,
                            y: isHighlighted ? 4 : 0
                        )

                    Image(systemName: app.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(app.color)
                }
                .frame(width: 68, height: 68)
                .scaleEffect(isHighlighted ? 1.09 : 1.0)
                .animation(.spring(response: 0.26, dampingFraction: 0.68), value: isHighlighted)

                Text(app.title)
                    .font(.system(size: 12, weight: isHighlighted ? .semibold : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(app.category)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
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
        .accessibilityHint("Double-tap to open \(app.title)")
    }

    private func handleAppTap(_ app: AppItem) {
        let now = CACurrentMediaTime()
        if lastTapId == app.id && (now - lastTapTime) <= 0.60 {
            // Confirmed double-tap!
            lastTapId = nil
            launchApp(app)
        } else {
            // First tap selects and highlights
            lastTapId = app.id
            lastTapTime = now
            hitRegistry.selectedLauncherTitle = app.title
            if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        }
    }

    private func launchApp(_ app: AppItem) {
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }

        let frame = CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)

        if let url = app.url {
            browser.newTab(url: url)
            if let existingBrowser = desktop.windows.first(where: { $0.title == "Browser" }) {
                desktop.restoreAndActivate(existingBrowser.id)
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
