import SwiftUI

/// User-configurable trackpad physics, pointer dynamics, and style preferences.
@MainActor
public final class TrackpadSettings: ObservableObject {
    public static let shared = TrackpadSettings()

    @Published public var pointerSensitivity: Double {
        didSet { UserDefaults.standard.set(pointerSensitivity, forKey: "kamihi.desktop.pointerSensitivity") }
    }

    /// 0 = nearly linear precision movement, 1 = balanced iPad/Mac-like acceleration,
    /// 2 = aggressive acceleration for large external displays.
    @Published public var pointerAcceleration: Double {
        didSet { UserDefaults.standard.set(pointerAcceleration, forKey: "kamihi.desktop.pointerAcceleration") }
    }

    @Published public var scrollSpeed: Double {
        didSet { UserDefaults.standard.set(scrollSpeed, forKey: "kamihi.desktop.scrollSpeed") }
    }

    @Published public var naturalScrolling: Bool {
        didSet { UserDefaults.standard.set(naturalScrolling, forKey: "kamihi.desktop.naturalScrolling") }
    }

    @Published public var scrollMomentum: Bool {
        didSet { UserDefaults.standard.set(scrollMomentum, forKey: "kamihi.desktop.scrollMomentum") }
    }

    @Published public var tapToClick: Bool {
        didSet { UserDefaults.standard.set(tapToClick, forKey: "kamihi.desktop.tapToClick") }
    }

    @Published public var dragLock: Bool {
        didSet { UserDefaults.standard.set(dragLock, forKey: "kamihi.desktop.dragLock") }
    }

    @Published public var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "kamihi.desktop.hapticsEnabled") }
    }

    @Published public var cursorStyle: CursorStyle {
        didSet { UserDefaults.standard.set(cursorStyle.rawValue, forKey: "kamihi.desktop.cursorStyle") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.pointerSensitivity = defaults.object(forKey: "kamihi.desktop.pointerSensitivity") as? Double ?? 1.20
        self.pointerAcceleration = defaults.object(forKey: "kamihi.desktop.pointerAcceleration") as? Double ?? 1.0
        self.scrollSpeed = defaults.object(forKey: "kamihi.desktop.scrollSpeed") as? Double ?? 1.0
        self.naturalScrolling = defaults.object(forKey: "kamihi.desktop.naturalScrolling") as? Bool ?? true
        self.scrollMomentum = defaults.object(forKey: "kamihi.desktop.scrollMomentum") as? Bool ?? true
        self.tapToClick = defaults.object(forKey: "kamihi.desktop.tapToClick") as? Bool ?? true
        self.dragLock = defaults.object(forKey: "kamihi.desktop.dragLock") as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: "kamihi.desktop.hapticsEnabled") as? Bool ?? true

        if let savedStyle = defaults.string(forKey: "kamihi.desktop.cursorStyle"),
           let style = CursorStyle(rawValue: savedStyle) {
            self.cursorStyle = style
        } else {
            self.cursorStyle = .kamihiDot
        }
    }
}
