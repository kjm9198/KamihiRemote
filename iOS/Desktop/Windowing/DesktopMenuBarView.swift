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

                HStack(spacing: 14) {
                    fileMenu
                    editMenu
                    viewMenu
                    windowMenu
                    helpMenu
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

                Button {
                    desktop.showControlCenter.toggle()
                    desktop.showNotifications = false
                } label: {
                    Image(systemName: "switch.2")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Control Center")

                Button {
                    desktop.showNotifications.toggle()
                    desktop.showControlCenter = false
                } label: {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(formattedDate(context.date))
                            .font(.system(size: 12.5, weight: .medium))
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Date and Time Notifications")
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

    private var fileMenu: some View {
        Menu {
            Button("New Window…") {
                desktop.openProductivityApp("Documents", frame: CGRect(x: 0.22, y: 0.18, width: 0.58, height: 0.62))
            }
            Button("New Browser Tab") {
                desktop.openProductivityApp("Browser", frame: CGRect(x: 0.18, y: 0.15, width: 0.64, height: 0.68))
            }
            Divider()
            Button("Close Window") {
                if let active = desktop.activeWindowID {
                    desktop.close(active)
                }
            }
        } label: {
            menuTitle("File")
        }
        .menuStyle(.borderlessButton)
    }

    private var editMenu: some View {
        Menu {
            Button("Undo") {}
                .disabled(true)
            Button("Redo") {}
                .disabled(true)
            Divider()
            Button("Cut") {}
            Button("Copy") {}
            Button("Paste") {}
            Button("Select All") {}
        } label: {
            menuTitle("Edit")
        }
        .menuStyle(.borderlessButton)
    }

    private var viewMenu: some View {
        Menu {
            Button(showWidgets ? "Hide Widgets" : "Show Widgets") {
                showWidgets.toggle()
            }
            Button("Change Wallpaper…") {
                showWallpaperPicker.toggle()
            }
            Divider()
            Button("Reset Windows Layout") {
                desktop.openVibeWorkspace()
            }
        } label: {
            menuTitle("View")
        }
        .menuStyle(.borderlessButton)
    }

    private var windowMenu: some View {
        Menu {
            Button("Minimize") {
                if let active = desktop.activeWindowID {
                    desktop.minimize(active)
                }
            }
            Button("Zoom / Fullscreen") {
                if let active = desktop.activeWindowID {
                    desktop.toggleMaximize(active)
                }
            }
            Divider()
            Button("Tile Window to Left") {
                desktop.snapActiveLeft()
            }
            Button("Tile Window to Right") {
                desktop.snapActiveRight()
            }
            Divider()
            Button("Bring All to Front") {}
        } label: {
            menuTitle("Window")
        }
        .menuStyle(.borderlessButton)
    }

    private var helpMenu: some View {
        Menu {
            Button("Desktop Tutorial…") {
                UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
            }
            Button("Display Diagnostics…") {
                desktop.openProductivityApp("Display Diagnostics", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
            }
        } label: {
            menuTitle("Help")
        }
        .menuStyle(.borderlessButton)
    }

    private func menuTitle(_ title: String) -> some View {
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
