import SwiftUI

/// Top desktop status bar using the same adaptive glass policy as Dock, App Library
/// and Settings. It stays information-dense without turning into a second mode UI.
public struct DesktopMenuBarView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @Binding var showWallpaperPicker: Bool
    @Binding var showWidgets: Bool

    public init(showWallpaperPicker: Binding<Bool>, showWidgets: Binding<Bool>) {
        self._showWallpaperPicker = showWallpaperPicker
        self._showWidgets = showWidgets
    }

    private var activeAppName: String { desktop.activeWindow?.title ?? "Desktop" }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 14) {
                Menu {
                    Button("About Kamihi Desktop") {}
                    Divider()
                    Button("Settings…", systemImage: "gearshape") {
                        desktop.openProductivityApp("Settings", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                    }
                    Button("Desktop Tutorial & Setup…", systemImage: "sparkles") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
                    }
                    Button("Wallpaper Chooser…", systemImage: "paintpalette") {
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
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)

                Text(activeAppName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    menuItem("File")
                    menuItem("Edit")
                    menuItem("View")
                    menuItem("Window")
                    menuItem("Help")
                }
            }

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(display.maximumFramesPerSecond >= 120 ? Color.cyan : Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(display.maximumFramesPerSecond) Hz")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.07), in: Capsule())

                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 4) {
                    Image(systemName: batterySymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(power.batteryLevel >= 0 && power.batteryLevel < 0.20 ? Color.red : Color.primary)
                    Text(power.batteryPercentageText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }

                Button { showWallpaperPicker.toggle() } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formattedDate(context.date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .desktopGlassSurface(cornerRadius: 0, elevated: false)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
        }
    }

    private func menuItem(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.85))
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
