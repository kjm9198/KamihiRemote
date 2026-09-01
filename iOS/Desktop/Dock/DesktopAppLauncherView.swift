import SwiftUI

/// Launchpad / App Library grid for opening applications on Kamihi Desktop.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    @State private var searchText = ""
    @State private var selectedAppTitle: String?

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
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: KamihiTheme.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                KamihiTheme.Colors.surfaceBackground.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: KamihiTheme.Spacing.lg) {
                        ForEach(filteredApps) { app in
                            appTile(app)
                        }
                    }
                    .padding(KamihiTheme.Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Single tap selects • double-tap opens")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 6)
            }
            .searchable(text: $searchText, prompt: "Search Apps & Utilities")
            .navigationTitle("App Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func appTile(_ app: AppItem) -> some View {
        let selected = selectedAppTitle == app.title
        return VStack(spacing: 8) {
            Image(systemName: app.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(app.color)
                .frame(width: 60, height: 60)
                .background(
                    selected ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.10), lineWidth: selected ? 1.5 : 1)
                )

            Text(app.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            launchApp(app.title)
        }
        .onTapGesture {
            selectedAppTitle = app.title
            if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.title)
        .accessibilityHint("Double-tap to open")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            launchApp(app.title)
        }
    }

    private func launchApp(_ title: String) {
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
