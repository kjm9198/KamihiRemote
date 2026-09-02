import SwiftUI

/// Launchpad / App Library grid for opening applications on Kamihi Desktop.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var desktop: DesktopSession
    @State private var searchText = ""

    private struct AppItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let category: String
    }

    private let apps: [AppItem] = [
        AppItem(title: "ChatGPT", icon: "sparkles", color: Color(red: 0.18, green: 0.72, blue: 0.62), category: "AI & Productivity"),
        AppItem(title: "Browser", icon: "globe", color: Color(red: 0.22, green: 0.58, blue: 0.94), category: "Web"),
        AppItem(title: "YouTube", icon: "play.rectangle.fill", color: Color(red: 0.94, green: 0.22, blue: 0.28), category: "Media"),
        AppItem(title: "Notes", icon: "note.text", color: Color(red: 0.92, green: 0.74, blue: 0.24), category: "Productivity"),
        AppItem(title: "Files", icon: "folder.fill", color: Color(red: 0.42, green: 0.68, blue: 0.94), category: "Utilities"),
        AppItem(title: "PDF Viewer", icon: "doc.text.fill", color: Color.red, category: "Documents"),
        AppItem(title: "Calculator", icon: "plus.slash.minus", color: Color.orange, category: "Utilities"),
        AppItem(title: "Clipboard", icon: "doc.on.clipboard.fill", color: Color.indigo, category: "Utilities"),
        AppItem(title: "Photos", icon: "photo.stack.fill", color: Color.purple, category: "Media"),
        AppItem(title: "Display Diagnostics", icon: "waveform.path.ecg.rectangle", color: Color.teal, category: "System")
    ]

    private var orderedApps: [AppItem] {
        let priorities = DesktopLaunchProfile.selected.preferredAppOrder
        guard !priorities.isEmpty else { return apps }
        return apps.sorted { lhs, rhs in
            let left = priorities.firstIndex(of: lhs.title) ?? Int.max
            let right = priorities.firstIndex(of: rhs.title) ?? Int.max
            if left == right { return appsIndex(lhs.title) < appsIndex(rhs.title) }
            return left < right
        }
    }

    private var filteredApps: [AppItem] {
        if searchText.isEmpty { return orderedApps }
        return orderedApps.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
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
            launchApp(app.title)
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
        .accessibilityHint("Opens \(app.title) on Kamihi Desktop")
        .accessibilityAddTraits(.isButton)
    }

    private func launchApp(_ title: String) {
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }

        // New apps start centered at 60% of the desktop instead of appearing
        // oversized or touching display edges.
        let frame = CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)
        desktop.openProductivityApp(title, frame: frame)
        dismiss()
    }

    private func appsIndex(_ title: String) -> Int {
        apps.firstIndex(where: { $0.title == title }) ?? Int.max
    }
}
