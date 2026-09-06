import SwiftUI

/// macOS-inspired menu bar using the same adaptive glass policy as Dock,
/// Applications, windows and Settings. Desktop-specific diagnostics stay in
/// Settings instead of cluttering the system bar.
public struct DesktopMenuBarView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var power = DesktopPowerMonitor.shared
    @Binding var showWallpaperPicker: Bool
    @Binding var showWidgets: Bool

    public init(showWallpaperPicker: Binding<Bool>, showWidgets: Binding<Bool>) {
        self._showWallpaperPicker = showWallpaperPicker
        self._showWidgets = showWidgets
    }

    private var activeAppName: String { desktop.activeWindow?.title ?? "Finder" }

    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                Menu {
                    Button("About Kamihi Desktop") {}
                    Divider()
                    Button("System Settings…", systemImage: "gearshape") {
                        desktop.openProductivityApp("Settings", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                    }
                    Button("Desktop Tutorial & Setup…", systemImage: "sparkles") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
                    }
                    Button("Wallpaper…", systemImage: "photo.on.rectangle.angled") {
                        showWallpaperPicker = true
                    }
                    Button(showWidgets ? "Hide Desktop Widgets" : "Show Desktop Widgets") {
                        showWidgets.toggle()
                    }
                    Divider()
                    Button("Close All Windows", role: .destructive) {
                        desktop.closeAllDesktopWindows()
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 18, height: 20)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Kamihi menu")

                Text(activeAppName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 16) {
                    menuItem("File")
                    menuItem("Edit")
                    menuItem("View")
                    menuItem("Window")
                    menuItem("Help")
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 13) {
                Image(systemName: "wifi")
                    .font(.system(size: 12.5, weight: .semibold))

                HStack(spacing: 4) {
                    Image(systemName: batterySymbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(power.batteryLevel >= 0 && power.batteryLevel < 0.20 ? Color.red : Color.primary)
                    Text(power.batteryPercentageText)
                        .font(.system(size: 11.5, weight: .medium))
                }

                Button { showWallpaperPicker.toggle() } label: {
                    Image(systemName: "rectangle.3.group.bubble.left.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Desktop controls")

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(formattedDate(context.date))
                        .font(.system(size: 12.5, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .desktopGlassSurface(cornerRadius: 0, elevated: false)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 0.5)
        }
    }

    private func menuItem(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.primary.opacity(0.88))
    }

    private var batterySymbol: String {
        if power.batteryState == .charging || power.batteryState == .full { return "battery.100.bolt" }
        let level = power.batteryLevel
        if level > 0.85 { return "battery.100" }
        if level > 0.60 { return "battery.75" }
        if level > 0.35 { return "battery.50" }
        if level > 0.15 { return "battery.25" }
        return "battery.0"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d  h:mm a"
        return formatter.string(from: date)
    }
}
