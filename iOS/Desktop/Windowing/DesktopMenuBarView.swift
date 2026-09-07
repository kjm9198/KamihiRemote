import SwiftUI

/// macOS-inspired menu bar with software-rendered glass dropdown popovers.
/// Works with both physical direct touches and synthetic software cursor clicks
/// on the non-interactive external display.
public struct DesktopMenuBarView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var hitRegistry = DesktopDockHitRegistry.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @Binding var showWallpaperPicker: Bool
    @Binding var showWidgets: Bool

    @State private var menuOrigins: [DesktopSession.MenuBarDropdown: CGFloat] = [
        .apple: 12,
        .file: 112,
        .edit: 154,
        .view: 198,
        .window: 248,
        .help: 314
    ]

    public init(showWallpaperPicker: Binding<Bool>, showWidgets: Binding<Bool>) {
        self._showWallpaperPicker = showWallpaperPicker
        self._showWidgets = showWidgets
    }

    private var activeAppName: String { desktop.activeWindow?.title ?? "Finder" }

    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                appleMenuButton

                Text(activeAppName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)

                menuButton(.file, title: "File")
                menuButton(.edit, title: "Edit")
                menuButton(.view, title: "View")
                menuButton(.window, title: "Window")
                menuButton(.help, title: "Help")
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
                    desktop.activeMenuBarMenu = nil
                } label: {
                    Image(systemName: "switch.2")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Control Center")

                Button {
                    desktop.showNotifications.toggle()
                    desktop.showControlCenter = false
                    desktop.activeMenuBarMenu = nil
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
        .overlay(alignment: .topLeading) {
            if let activeMenu = desktop.activeMenuBarMenu {
                dropdownPopover(for: activeMenu)
                    .offset(x: menuOrigins[activeMenu] ?? 12, y: 29)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading)))
            }
        }
    }

    private var appleMenuButton: some View {
        let isActive = desktop.activeMenuBarMenu == .apple
        let isHovered = hitRegistry.hoveredMenuBarMenu == .apple

        return Button {
            toggleMenu(.apple)
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .frame(width: 24, height: 22)
                .background(
                    isActive
                        ? AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor))
                        : (isHovered ? AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.09))) : AnyView(EmptyView()))
                )
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        menuOrigins[.apple] = geo.frame(in: .named("desktopSurface")).minX
                    }
                    .onChange(of: geo.frame(in: .named("desktopSurface")).minX) { _, newX in
                        menuOrigins[.apple] = newX
                    }
                    .preference(
                        key: DockGeometryPreferenceKey.self,
                        value: [DockItemGeometryPreference(
                            target: .menuBarButton(.apple),
                            frameInSurface: geo.frame(in: .named("desktopSurface"))
                        )]
                    )
            }
        )
        .accessibilityLabel("Kamihi menu")
    }

    private func menuButton(_ menu: DesktopSession.MenuBarDropdown, title: String) -> some View {
        let isActive = desktop.activeMenuBarMenu == menu
        let isHovered = hitRegistry.hoveredMenuBarMenu == menu

        return Button {
            toggleMenu(menu)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.white : Color.primary.opacity(0.88))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    isActive
                        ? AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor))
                        : (isHovered ? AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.09))) : AnyView(EmptyView()))
                )
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        menuOrigins[menu] = geo.frame(in: .named("desktopSurface")).minX
                    }
                    .onChange(of: geo.frame(in: .named("desktopSurface")).minX) { _, newX in
                        menuOrigins[menu] = newX
                    }
                    .preference(
                        key: DockGeometryPreferenceKey.self,
                        value: [DockItemGeometryPreference(
                            target: .menuBarButton(menu),
                            frameInSurface: geo.frame(in: .named("desktopSurface"))
                        )]
                    )
            }
        )
    }

    private func toggleMenu(_ menu: DesktopSession.MenuBarDropdown) {
        if desktop.activeMenuBarMenu == menu {
            desktop.activeMenuBarMenu = nil
        } else {
            desktop.activeMenuBarMenu = menu
            desktop.showControlCenter = false
            desktop.showNotifications = false
        }
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
    }

    private struct MenuItem: Identifiable {
        let id: String
        let title: String
        let icon: String?
        let shortcut: String?
        let isDestructive: Bool
        let isDivider: Bool
        let action: () -> Void

        init(id: String, title: String, icon: String? = nil, shortcut: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            self.icon = icon
            self.shortcut = shortcut
            self.isDestructive = isDestructive
            self.isDivider = false
            self.action = action
        }

        static func divider(_ id: String) -> MenuItem {
            MenuItem(dividerId: id)
        }

        private init(dividerId: String) {
            self.id = dividerId
            self.title = ""
            self.icon = nil
            self.shortcut = nil
            self.isDestructive = false
            self.isDivider = true
            self.action = {}
        }
    }

    private func dropdownPopover(for menu: DesktopSession.MenuBarDropdown) -> some View {
        let items = itemsForMenu(menu)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                if item.isDivider {
                    Divider()
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                } else {
                    dropdownRow(item)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .frame(width: 228)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 12, y: 8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .menuBarDropdownContainer,
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
    }

    private func dropdownRow(_ item: MenuItem) -> some View {
        let isHovered = hitRegistry.hoveredMenuBarActionId == item.id
        return Button {
            item.action()
            desktop.activeMenuBarMenu = nil
            if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        } label: {
            HStack(spacing: 8) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 16)
                        .foregroundStyle(item.isDestructive ? Color.red : (isHovered ? Color.white : Color.primary.opacity(0.85)))
                } else {
                    Spacer().frame(width: 16)
                }

                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(item.isDestructive ? Color.red : (isHovered ? Color.white : Color.primary))

                Spacer(minLength: 8)

                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.9) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(
                isHovered
                    ? AnyView(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(item.isDestructive ? Color.red : Color.accentColor))
                    : AnyView(EmptyView())
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DockGeometryPreferenceKey.self,
                    value: [DockItemGeometryPreference(
                        target: .menuBarDropdownItem(actionId: item.id),
                        frameInSurface: geo.frame(in: .named("desktopSurface"))
                    )]
                )
            }
        )
    }

    private func itemsForMenu(_ menu: DesktopSession.MenuBarDropdown) -> [MenuItem] {
        switch menu {
        case .apple:
            return [
                MenuItem(id: "apple.about", title: "About Kamihi Desktop", icon: "info.circle") {
                    desktop.openProductivityApp("Settings", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                },
                .divider("apple.div1"),
                MenuItem(id: "apple.settings", title: "System Settings…", icon: "gearshape", shortcut: "⌘,") {
                    desktop.openProductivityApp("Settings", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                },
                MenuItem(id: "apple.tutorial", title: "Desktop Tutorial & Setup…", icon: "sparkles") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
                },
                MenuItem(id: "apple.wallpaper", title: "Wallpaper…", icon: "photo.on.rectangle.angled") {
                    showWallpaperPicker = true
                    desktop.showWallpaperPicker = true
                },
                MenuItem(id: "apple.widgets", title: showWidgets ? "Hide Desktop Widgets" : "Show Desktop Widgets", icon: "square.text.square") {
                    showWidgets.toggle()
                },
                .divider("apple.div2"),
                MenuItem(id: "apple.closeAll", title: "Close All Windows", icon: "xmark.rectangle", isDestructive: true) {
                    desktop.closeAllDesktopWindows()
                }
            ]

        case .file:
            return [
                MenuItem(id: "file.newWindow", title: "New Document Window…", icon: "doc.badge.plus", shortcut: "⌘N") {
                    desktop.openProductivityApp("Documents", frame: CGRect(x: 0.22, y: 0.18, width: 0.58, height: 0.62))
                },
                MenuItem(id: "file.newTab", title: "New Browser Tab", icon: "plus.square.on.square", shortcut: "⌘T") {
                    desktop.openProductivityApp("Browser", frame: CGRect(x: 0.18, y: 0.15, width: 0.64, height: 0.68))
                    DesktopBrowserState.shared.newTab()
                },
                .divider("file.div1"),
                MenuItem(id: "file.closeWindow", title: "Close Window", icon: "xmark", shortcut: "⌘W") {
                    if let active = desktop.activeWindowID {
                        desktop.close(active)
                    }
                }
            ]

        case .edit:
            return [
                MenuItem(id: "edit.cut", title: "Cut", icon: "scissors", shortcut: "⌘X") {
                    if let _ = UIPasteboard.general.string {
                        desktop.deleteBackwardInActiveDesktopField()
                    }
                },
                MenuItem(id: "edit.copy", title: "Copy", icon: "doc.on.doc", shortcut: "⌘C") {
                    // Copy action
                },
                MenuItem(id: "edit.paste", title: "Paste", icon: "doc.on.clipboard", shortcut: "⌘V") {
                    if let str = UIPasteboard.general.string {
                        desktop.typeIntoActiveDesktopField(str)
                    }
                },
                .divider("edit.div1"),
                MenuItem(id: "edit.selectAll", title: "Select All", icon: "selection.pin.in.out", shortcut: "⌘A") {
                    if let title = desktop.activeWindow?.title {
                        DesktopWebInputRegistry.shared.click(key: title, x: 0.5, y: 0.5) { _ in }
                    }
                }
            ]

        case .view:
            return [
                MenuItem(id: "view.widgets", title: showWidgets ? "Hide Widgets" : "Show Widgets", icon: "square.text.square") {
                    showWidgets.toggle()
                },
                MenuItem(id: "view.wallpaper", title: "Change Wallpaper…", icon: "paintpalette") {
                    showWallpaperPicker.toggle()
                    desktop.showWallpaperPicker.toggle()
                },
                MenuItem(id: "view.dockAutohide", title: desktop.autohideDock ? "Keep Dock Visible" : "Automatically Hide Dock", icon: "dock.rectangle") {
                    desktop.autohideDock.toggle()
                },
                .divider("view.div1"),
                MenuItem(id: "view.resetLayout", title: "Reset Windows Layout", icon: "arrow.counterclockwise.circle") {
                    desktop.openVibeWorkspace()
                }
            ]

        case .window:
            return [
                MenuItem(id: "window.minimize", title: "Minimize", icon: "minus", shortcut: "⌘M") {
                    if let active = desktop.activeWindowID {
                        desktop.minimize(active)
                    }
                },
                MenuItem(id: "window.zoom", title: "Zoom / Fullscreen", icon: "arrow.up.left.and.arrow.down.right") {
                    if let active = desktop.activeWindowID {
                        desktop.toggleMaximize(active)
                    }
                },
                .divider("window.div1"),
                MenuItem(id: "window.tileLeft", title: "Tile Window to Left", icon: "rectangle.leadinghalf.filled") {
                    desktop.snapActiveLeft()
                },
                MenuItem(id: "window.tileRight", title: "Tile Window to Right", icon: "rectangle.trailinghalf.filled") {
                    desktop.snapActiveRight()
                },
                .divider("window.div2"),
                MenuItem(id: "window.bringFront", title: "Bring All to Front", icon: "macwindow.on.rectangle") {
                    for window in desktop.windows {
                        desktop.restoreAndActivate(window.id)
                    }
                }
            ]

        case .help:
            return [
                MenuItem(id: "help.tutorial", title: "Desktop Tutorial…", icon: "questionmark.circle") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
                },
                MenuItem(id: "help.diagnostics", title: "Display Diagnostics…", icon: "waveform.path.ecg.rectangle") {
                    desktop.openProductivityApp("Display Diagnostics", frame: CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.72))
                }
            ]
        }
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

