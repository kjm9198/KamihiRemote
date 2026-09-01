import SwiftUI

/// Floating iPadOS-inspired dock on the external display.
struct DesktopDockView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.colorScheme) private var colorScheme
    var onOpenLauncher: () -> Void

    private let pinnedApps: [(title: String, icon: String, color: Color)] = [
        ("ChatGPT", "sparkles", Color(red: 0.18, green: 0.72, blue: 0.62)),
        ("Browser", "globe", Color(red: 0.22, green: 0.58, blue: 0.94)),
        ("YouTube", "play.rectangle.fill", Color(red: 0.94, green: 0.22, blue: 0.28)),
        ("Notes", "note.text", Color(red: 0.92, green: 0.74, blue: 0.24)),
        ("Files", "folder.fill", Color(red: 0.42, green: 0.68, blue: 0.94))
    ]

    var body: some View {
        HStack(spacing: KamihiTheme.Spacing.xs) {
            Button(action: onOpenLauncher) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(KamihiTheme.Colors.activeControlFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open App Library")

            Divider()
                .frame(height: 24)

            ForEach(pinnedApps, id: \.title) { app in
                dockAppButton(title: app.title, icon: app.icon, color: app.color)
            }

            Spacer(minLength: 12)

            HStack(spacing: KamihiTheme.Spacing.xs) {
                Text(Date(), style: .time)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(KamihiTheme.Colors.subtleBorder, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16),
            radius: 14,
            x: 0,
            y: 7
        )
    }

    private func dockAppButton(title: String, icon: String, color: Color) -> some View {
        let isRunning = desktop.windows.contains(where: { $0.title == title })
        let isMinimized = desktop.windows.first(where: { $0.title == title })?.isMinimized ?? false
        let isActive = desktop.activeWindow?.title == title

        return Button {
            desktop.openProductivityApp(title)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(
                        isActive ? KamihiTheme.Colors.activeControlFill : KamihiTheme.Colors.controlFill,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Circle()
                    .fill(isRunning ? (isMinimized ? Color.orange : Color.primary) : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Active" : (isRunning ? "Running" : "Not running"))
    }
}
