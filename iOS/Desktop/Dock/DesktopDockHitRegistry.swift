import SwiftUI

/// Geometry tracking and hit-testing registry for external desktop dock items.
/// Allows software cursor clicks from the iPhone trackpad to activate dock apps
/// and toggle the Applications chooser without requiring physical touch on the monitor.
@MainActor
public final class DesktopDockHitRegistry: ObservableObject {
    public static let shared = DesktopDockHitRegistry()

    public enum Target: Equatable {
        case launcherToggle
        case wallpaperToggle
        case wallpaperOption(id: String)
        case wallpaperDismiss
        case app(title: String)
        case launcherApp(title: String, url: URL?)
        case launcherContainer
        case launcherDismiss
        case menuBarButton(MenuBarDropdown)
        case menuBarDropdownItem(actionId: String)
        case menuBarDropdownContainer
        case menuBarDismiss
    }

    public struct Entry: Identifiable {
        public let id = UUID()
        public let target: Target
        public let normalizedFrame: CGRect

        public init(target: Target, normalizedFrame: CGRect) {
            self.target = target
            self.normalizedFrame = normalizedFrame
        }
    }

    @Published public private(set) var entries: [Entry] = []
    @Published public var isLauncherOpen: Bool = false {
        didSet {
            if !isLauncherOpen {
                if hoveredAppTitle != nil { hoveredAppTitle = nil }
                if selectedLauncherTitle != nil { selectedLauncherTitle = nil }
                lastLauncherClickSample = nil
            }
        }
    }

    @Published public var hoveredAppTitle: String? = nil
    @Published public var selectedLauncherTitle: String? = nil
    @Published public var hoveredDockTitle: String? = nil
    @Published public var isLauncherToggleHovered: Bool = false
    @Published public var hoveredMenuBarActionId: String? = nil
    @Published public var hoveredMenuBarMenu: MenuBarDropdown? = nil
    public var lastLauncherClickSample: (title: String, time: TimeInterval)? = nil

    public var onToggleLauncher: (() -> Void)?
    public var onDismissLauncher: (() -> Void)?
    public var onToggleWallpaper: (() -> Void)?
    public var onLaunchApp: ((String, URL?) -> Void)?

    private init() {}

    /// SwiftUI geometry preferences can be re-emitted while the pointer moves even
    /// when the Dock/App Library layout did not actually change. Publishing a new
    /// array on every identical preference pass invalidates all observers and can
    /// make high-rate hardware mouse movement feel less direct. Entry UUIDs are
    /// intentionally ignored here; target + normalized geometry are the semantic
    /// identity used by hit testing.
    public func update(entries: [Entry]) {
        guard !Self.hasSameGeometry(self.entries, entries) else { return }
        self.entries = entries
    }

    private static func hasSameGeometry(_ lhs: [Entry], _ rhs: [Entry]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.target == right.target && left.normalizedFrame == right.normalizedFrame
        }
    }

    public func clear() {
        if !entries.isEmpty { self.entries.removeAll() }
        if hoveredAppTitle != nil { hoveredAppTitle = nil }
        if selectedLauncherTitle != nil { selectedLauncherTitle = nil }
        if hoveredDockTitle != nil { hoveredDockTitle = nil }
        if isLauncherToggleHovered { isLauncherToggleHovered = false }
        if hoveredMenuBarActionId != nil { hoveredMenuBarActionId = nil }
        if hoveredMenuBarMenu != nil { hoveredMenuBarMenu = nil }
    }

    public func updateHover(at point: CGPoint) {
        if DesktopSession.shared.activeMenuBarMenu != nil {
            for entry in entries.reversed() {
                if case .menuBarButton(let menu) = entry.target {
                    if entry.normalizedFrame.insetBy(dx: -0.004, dy: -0.004).contains(point) {
                        if DesktopSession.shared.activeMenuBarMenu != menu {
                            DesktopSession.shared.activeMenuBarMenu = menu
                        }
                        if hoveredMenuBarMenu != menu { hoveredMenuBarMenu = menu }
                        return
                    }
                }
            }

            for entry in entries.reversed() {
                if case .menuBarDropdownItem(let actionId) = entry.target {
                    if entry.normalizedFrame.insetBy(dx: -0.002, dy: -0.002).contains(point) {
                        if hoveredMenuBarActionId != actionId {
                            hoveredMenuBarActionId = actionId
                        }
                        return
                    }
                }
            }
            if hoveredMenuBarActionId != nil { hoveredMenuBarActionId = nil }
            return
        }

        if hoveredMenuBarActionId != nil { hoveredMenuBarActionId = nil }
        if hoveredMenuBarMenu != nil { hoveredMenuBarMenu = nil }

        if isLauncherOpen {
            if hoveredDockTitle != nil { hoveredDockTitle = nil }
            if isLauncherToggleHovered { isLauncherToggleHovered = false }

            for entry in entries.reversed() {
                if case .launcherApp(let title, _) = entry.target {
                    let expanded = entry.normalizedFrame.insetBy(dx: -0.008, dy: -0.008)
                    if expanded.contains(point) {
                        if hoveredAppTitle != title {
                            hoveredAppTitle = title
                        }
                        return
                    }
                }
            }
            if hoveredAppTitle != nil { hoveredAppTitle = nil }
            return
        }

        if hoveredAppTitle != nil { hoveredAppTitle = nil }

        var nextDockTitle: String?
        var nextLauncherHover = false
        for entry in entries.reversed() {
            let expanded = entry.normalizedFrame.insetBy(dx: -0.006, dy: -0.006)
            guard expanded.contains(point) else { continue }
            switch entry.target {
            case .app(let title):
                nextDockTitle = title
            case .launcherToggle:
                nextLauncherHover = true
            case .wallpaperToggle:
                nextDockTitle = "Wallpaper"
            case .menuBarButton(let menu):
                if hoveredMenuBarMenu != menu { hoveredMenuBarMenu = menu }
            default:
                break
            }
            if nextDockTitle != nil || nextLauncherHover { break }
        }

        if hoveredDockTitle != nextDockTitle { hoveredDockTitle = nextDockTitle }
        if isLauncherToggleHovered != nextLauncherHover { isLauncherToggleHovered = nextLauncherHover }
    }

    public func hitTest(at point: CGPoint) -> Target? {
        if DesktopSession.shared.activeMenuBarMenu != nil {
            for entry in entries.reversed() {
                if case .menuBarDropdownItem = entry.target {
                    let expanded = entry.normalizedFrame.insetBy(dx: -0.004, dy: -0.004)
                    if expanded.contains(point) {
                        return entry.target
                    }
                }
            }

            for entry in entries.reversed() {
                if case .menuBarButton = entry.target {
                    let expanded = entry.normalizedFrame.insetBy(dx: -0.004, dy: -0.004)
                    if expanded.contains(point) {
                        return entry.target
                    }
                }
            }

            for entry in entries {
                if case .menuBarDropdownContainer = entry.target,
                   entry.normalizedFrame.contains(point) {
                    return .menuBarDropdownContainer
                }
            }

            return .menuBarDismiss
        }

        if isLauncherOpen {
            // First hit-test launcher app tiles.
            for entry in entries.reversed() {
                if case .launcherApp = entry.target {
                    let expanded = entry.normalizedFrame.insetBy(dx: -0.008, dy: -0.008)
                    if expanded.contains(point) {
                        return entry.target
                    }
                }
            }

            // Next check if inside launcher container.
            for entry in entries {
                if case .launcherContainer = entry.target,
                   entry.normalizedFrame.contains(point) {
                    return .launcherContainer
                }
            }

            // Clicked outside launcher while open -> dismiss.
            return .launcherDismiss
        }

        if DesktopSession.shared.showWallpaperPicker {
            for entry in entries.reversed() {
                if case .wallpaperOption = entry.target {
                    let expanded = entry.normalizedFrame.insetBy(dx: -0.006, dy: -0.006)
                    if expanded.contains(point) {
                        return entry.target
                    }
                }
            }
            return .wallpaperDismiss
        }

        // Normal dock & menu bar hit test.
        for entry in entries.reversed() {
            switch entry.target {
            case .app, .launcherToggle, .wallpaperToggle, .menuBarButton:
                let expanded = entry.normalizedFrame.insetBy(dx: -0.006, dy: -0.006)
                if expanded.contains(point) {
                    return entry.target
                }
            default:
                continue
            }
        }
        return nil
    }
}

public struct DockItemGeometryPreference: Equatable {
    public let target: DesktopDockHitRegistry.Target
    public let frameInSurface: CGRect

    public init(target: DesktopDockHitRegistry.Target, frameInSurface: CGRect) {
        self.target = target
        self.frameInSurface = frameInSurface
    }
}

public struct DockGeometryPreferenceKey: PreferenceKey {
    public static var defaultValue: [DockItemGeometryPreference] = []
    public static func reduce(value: inout [DockItemGeometryPreference], nextValue: () -> [DockItemGeometryPreference]) {
        value.append(contentsOf: nextValue())
    }
}
