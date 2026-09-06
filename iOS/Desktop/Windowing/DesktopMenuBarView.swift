import SwiftUI

/// Top macOS menu bar for Kamihi Desktop with Apple/Kamihi menu, active app title,
/// standard menus, 120Hz ProMotion badge, battery status, and date/time.
public struct DesktopMenuBarView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @ObservedObject private var wallpaperManager = DesktopWallpaperManager.shared
    @Binding var showWallpaperPicker: Bool
    @Binding var showWidgets: Bool

    public init(
        showWallpaperPicker: Binding<Bool>,
        showWidgets: Binding<Bool>
    ) {
        self._showWallpaperPicker = showWallpaperPicker
        self._showWidgets = showWidgets
    }

    private var activeAppName: String {
        desktop.activeWindow?.title ?? "Finder"
    }

    public var body: some View {
        HStack(spacing: 12) {
            // MARK: - Left: Apple/Kamihi Logo & Menus
            HStack(spacing: 14) {
                Menu {
                    Button("About Kamihi Desktop") {}
                    Divider()
                    Button("Desktop Tutorial & Setup...") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
                    }
                    Button("Wallpaper Chooser...") {
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
                    Image(systemName: "apple.logo")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)

                Text(activeAppName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                HStack(spacing: 12) {
                    menuItem("File")
                    menuItem("Edit")
                    menuItem("View")
                    menuItem("Window")
                    menuItem("Help")
                }
            }

            Spacer()

            // MARK: - Right: System Status & 120Hz ProMotion Badge
            HStack(spacing: 10) {
                // 120Hz ProMotion Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(display.maximumFramesPerSecond >= 120 ? Color.cyan : Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(display.maximumFramesPerSecond) Hz")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(display.maximumFramesPerSecond >= 120 ? Color.cyan : Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.28), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        display.maximumFramesPerSecond >= 120 ? Color.cyan.opacity(0.4) : Color.white.opacity(0.12),
                        lineWidth: 0.8
                    )
                }

                // Wi-Fi
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)

                // Battery
                HStack(spacing: 4) {
                    Image(systemName: batterySymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(power.batteryLevel >= 0 && power.batteryLevel < 0.20 ? Color.red : Color.primary)
                    Text(power.batteryPercentageText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primary)
                }

                // Control Center / Wallpaper Toggle
                Button {
                    showWallpaperPicker.toggle()
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.85))
                }
                .buttonStyle(.plain)

                // Live Date & Time
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formattedDate(context.date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
        }
    }

    private func menuItem(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.85))
    }

    private var batterySymbol: String {
        if power.batteryState == .charging || power.batteryState == .full {
            return "battery.100.bolt"
        }
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
