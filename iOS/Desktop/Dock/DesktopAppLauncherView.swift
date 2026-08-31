import SwiftUI

/// Launchpad / App Library grid for opening applications on Kamihi Desktop.
struct DesktopAppLauncherView: View {
    @Environment(\.dismiss) private var dismiss
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

    private var filteredApps: [AppItem] {
        if searchText.isEmpty { return apps }
        return apps.filter {
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
                Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: KamihiTheme.Spacing.lg) {
                        ForEach(filteredApps) { app in
                            Button {
                                launchApp(app.title)
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: app.icon)
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(app.color)
                                        .frame(width: 60, height: 60)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                        )

                                    Text(app.title)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(KamihiTheme.Spacing.lg)
                }
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

    private func launchApp(_ title: String) {
        desktop.openProductivityApp(title)
        dismiss()
    }
}
