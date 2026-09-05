import SwiftUI

/// Launchpad / App Library grid for opening applications on Kamihi Desktop.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var browser = DesktopBrowserState.shared
    @State private var searchText = ""

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

    /// One persistent desktop has one stable app library. Legacy startup-profile
    /// preferences no longer reorder or shape the normal launcher.
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
        GridItem(.adaptive(minimum: 96, maximum: 124), spacing: DesktopShellMetrics.standardSpacing)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesktopShellPalette.canvas.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: DesktopShellMetrics.sectionSpacing) {
                        ForEach(filteredApps) { app in
                            appTile(app)
                        }
                    }
                    .padding(DesktopShellMetrics.sectionSpacing)
                }
                .scrollIndicators(.hidden)
            }
            .searchable(text: $searchText, prompt: "Search Apps & Utilities")
            .navigationTitle("App Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: DesktopShellMetrics.minimumHitTarget, minHeight: DesktopShellMetrics.minimumHitTarget)
                }
            }
        }
        .desktopShellTheme()
    }

    private func appTile(_ app: AppItem) -> some View {
        Button {
            launchApp(app)
        } label: {
            VStack(spacing: DesktopShellMetrics.compactSpacing) {
                Image(systemName: app.icon)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(app.color)
                    .frame(width: 64, height: 64)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(reduceTransparency ? DesktopShellPalette.secondaryCanvas : DesktopShellPalette.elevatedCanvas.opacity(0.82))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DesktopShellPalette.separator.opacity(reduceTransparency ? 0.62 : 0.30), lineWidth: reduceTransparency ? 1 : 0.5)
                    }

                Text(app.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DesktopShellPalette.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(app.category)
                    .font(.caption2)
                    .foregroundStyle(DesktopShellPalette.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.title)
        .accessibilityHint(app.url == nil ? "Opens \(app.title) on Kamihi Desktop" : "Opens pinned website \(app.title) in Kamihi Browser")
        .accessibilityAddTraits(.isButton)
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
            // Reopening a running/minimized app should reveal exactly that window
            // where the user left it. Do not silently resize or reposition it.
            desktop.restoreAndActivate(existing.id)
        } else {
            desktop.openProductivityApp(app.title, frame: frame)
        }
        dismiss()
    }
}
