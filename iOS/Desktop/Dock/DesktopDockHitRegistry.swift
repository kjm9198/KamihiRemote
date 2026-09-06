import SwiftUI

/// Geometry tracking and hit-testing registry for external desktop dock items.
/// Allows software cursor clicks from the iPhone trackpad to activate dock apps
/// and toggle the Applications chooser without requiring physical touch on the monitor.
@MainActor
public final class DesktopDockHitRegistry: ObservableObject {
    public static let shared = DesktopDockHitRegistry()

    public enum Target: Equatable {
        case launcherToggle
        case app(title: String)
        case launcherApp(title: String, url: URL?)
        case launcherContainer
        case launcherDismiss
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
                hoveredAppTitle = nil
                selectedLauncherTitle = nil
                lastLauncherClickSample = nil
            }
        }
    }

    @Published public var hoveredAppTitle: String? = nil
    @Published public var selectedLauncherTitle: String? = nil
    @Published public var hoveredDockTitle: String? = nil
    @Published public var isLauncherToggleHovered: Bool = false
    public var lastLauncherClickSample: (title: String, time: TimeInterval)? = nil

    public var onToggleLauncher: (() -> Void)?
    public var onDismissLauncher: (() -> Void)?
    public var onLaunchApp: ((String, URL?) -> Void)?

    private init() {}

    public func update(entries: [Entry]) {
        self.entries = entries
    }

    public func clear() {
        self.entries.removeAll()
        hoveredAppTitle = nil
        selectedLauncherTitle = nil
        hoveredDockTitle = nil
        isLauncherToggleHovered = false
    }

    public func updateHover(at point: CGPoint) {
        if isLauncherOpen {
            hoveredDockTitle = nil
            isLauncherToggleHovered = false

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
            default:
                break
            }
            if nextDockTitle != nil || nextLauncherHover { break }
        }

        if hoveredDockTitle != nextDockTitle { hoveredDockTitle = nextDockTitle }
        if isLauncherToggleHovered != nextLauncherHover { isLauncherToggleHovered = nextLauncherHover }
    }

    public func hitTest(at point: CGPoint) -> Target? {
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

        // Normal dock hit test.
        for entry in entries.reversed() {
            switch entry.target {
            case .app, .launcherToggle:
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
