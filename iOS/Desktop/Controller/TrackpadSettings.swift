import SwiftUI

/// Calibrated desktop pointer profiles. These stay intentionally small and
/// deterministic so the phone controller can offer predictable tuning without
/// changing gesture semantics or relying on private pointer APIs.
public enum DesktopPointerProfile: String, CaseIterable, Identifiable {
    case precision
    case balanced
    case fast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .precision: return "Precision"
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        }
    }

    public var sensitivity: Double {
        switch self {
        case .precision: return 0.92
        case .balanced: return 1.20
        case .fast: return 1.55
        }
    }

    public var acceleration: Double {
        switch self {
        case .precision: return 0.45
        case .balanced: return 1.00
        case .fast: return 1.35
        }
    }
}

/// User-configurable trackpad physics, pointer dynamics, and style preferences.
@MainActor
public final class TrackpadSettings: ObservableObject {
    public static let shared = TrackpadSettings()

    public static let pointerSensitivityRange: ClosedRange<Double> = 0.45...2.40
    public static let pointerAccelerationRange: ClosedRange<Double> = 0.0...2.0
    public static let scrollSpeedRange: ClosedRange<Double> = 0.55...3.0

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

        // Clamp persisted values on load. This protects the Desktop controller from
        // stale/bad defaults (including values written by older development builds)
        // that could otherwise make the software pointer effectively unusable.
        let savedSensitivity = defaults.object(forKey: "kamihi.desktop.pointerSensitivity") as? Double
        let savedAcceleration = defaults.object(forKey: "kamihi.desktop.pointerAcceleration") as? Double
        self.pointerSensitivity = Self.normalizedPointerSensitivity(savedSensitivity ?? DesktopPointerProfile.balanced.sensitivity)
        self.pointerAcceleration = Self.normalizedPointerAcceleration(savedAcceleration ?? DesktopPointerProfile.balanced.acceleration)

        // v2 raises the baseline scroll travel so short two-finger strokes feel
        // useful on a desktop canvas. Existing faster custom values are kept.
        let savedScrollSpeed = defaults.object(forKey: "kamihi.desktop.scrollSpeed") as? Double
        let scrollTuningVersion = defaults.integer(forKey: "kamihi.desktop.scrollTuningVersion")
        let resolvedScrollSpeed: Double
        if scrollTuningVersion < 2 {
            resolvedScrollSpeed = max(savedScrollSpeed ?? 1.0, 1.35)
        } else {
            resolvedScrollSpeed = savedScrollSpeed ?? 1.35
        }
        self.scrollSpeed = Self.normalizedScrollSpeed(resolvedScrollSpeed)

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

        if scrollTuningVersion < 2 {
            defaults.set(2, forKey: "kamihi.desktop.scrollTuningVersion")
        }

        // Persist only the normalized resolved values so subsequent launches cannot
        // reintroduce an out-of-range pointer/scroll configuration.
        defaults.set(pointerSensitivity, forKey: "kamihi.desktop.pointerSensitivity")
        defaults.set(pointerAcceleration, forKey: "kamihi.desktop.pointerAcceleration")
        defaults.set(scrollSpeed, forKey: "kamihi.desktop.scrollSpeed")
    }

    public func applyPointerProfile(_ profile: DesktopPointerProfile) {
        pointerSensitivity = profile.sensitivity
        pointerAcceleration = profile.acceleration
        UserDefaults.standard.set(profile.rawValue, forKey: "kamihi.desktop.pointerProfile")
    }

    public var matchingPointerProfile: DesktopPointerProfile? {
        DesktopPointerProfile.allCases.first { profile in
            abs(pointerSensitivity - profile.sensitivity) < 0.001 &&
            abs(pointerAcceleration - profile.acceleration) < 0.001
        }
    }

    public static func normalizedPointerSensitivity(_ value: Double) -> Double {
        min(max(value, pointerSensitivityRange.lowerBound), pointerSensitivityRange.upperBound)
    }

    public static func normalizedPointerAcceleration(_ value: Double) -> Double {
        min(max(value, pointerAccelerationRange.lowerBound), pointerAccelerationRange.upperBound)
    }

    public static func normalizedScrollSpeed(_ value: Double) -> Double {
        min(max(value, scrollSpeedRange.lowerBound), scrollSpeedRange.upperBound)
    }
}
