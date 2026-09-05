import SwiftUI

/// Calibrated desktop pointer profiles. These stay intentionally small and
/// deterministic so the phone controller can offer predictable tuning without
/// changing gesture semantics or relying on private pointer APIs.
public enum DesktopPointerProfile: String, CaseIterable, Identifiable {
    case precision
    case direct
    case balanced
    case fast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .precision: return "Precision"
        case .direct: return "Direct"
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        }
    }

    public var sensitivity: Double {
        switch self {
        case .precision: return 0.92
        case .direct: return 1.08
        case .balanced: return 1.12
        case .fast: return 1.55
        }
    }

    public var acceleration: Double {
        switch self {
        case .precision: return 0.45
        case .direct: return 0.15
        case .balanced: return 0.82
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

        // Pointer tuning v3 makes the Direct profile the baseline for untouched
        // installations. It keeps low-speed movement close to the finger with
        // only mild acceleration, which is a better default for precise title-bar,
        // close-button and browser targeting on a 1080p external desktop. Any
        // explicitly customized sensitivity/acceleration values remain unchanged.
        let oldStockSensitivity = DesktopPointerProfile.balanced.sensitivity
        let oldStockAcceleration = DesktopPointerProfile.balanced.acceleration
        let pointerTuningVersion = defaults.integer(forKey: "kamihi.desktop.pointerTuningVersion")
        let savedSensitivity = defaults.object(forKey: "kamihi.desktop.pointerSensitivity") as? Double
        let savedAcceleration = defaults.object(forKey: "kamihi.desktop.pointerAcceleration") as? Double
        let shouldMigrateStockPointer = pointerTuningVersion < 3 &&
            (savedSensitivity == nil || abs((savedSensitivity ?? oldStockSensitivity) - oldStockSensitivity) < 0.001) &&
            (savedAcceleration == nil || abs((savedAcceleration ?? oldStockAcceleration) - oldStockAcceleration) < 0.001)

        let resolvedSensitivity = shouldMigrateStockPointer
            ? DesktopPointerProfile.direct.sensitivity
            : (savedSensitivity ?? DesktopPointerProfile.direct.sensitivity)
        let resolvedAcceleration = shouldMigrateStockPointer
            ? DesktopPointerProfile.direct.acceleration
            : (savedAcceleration ?? DesktopPointerProfile.direct.acceleration)

        // Clamp persisted values on load. This protects the Desktop controller from
        // stale/bad defaults (including values written by older development builds)
        // that could otherwise make the software pointer effectively unusable.
        self.pointerSensitivity = Self.normalizedPointerSensitivity(resolvedSensitivity)
        self.pointerAcceleration = Self.normalizedPointerAcceleration(resolvedAcceleration)

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

        // Drag Lock is opt-in. A fresh/default installation should behave like a
        // direct trackpad: hold to move a title bar and release to drop it. This
        // prevents a second-tap hold from leaving a window attached to the pointer
        // unexpectedly. Explicit user choices already persisted in UserDefaults
        // are preserved exactly.
        self.dragLock = defaults.object(forKey: "kamihi.desktop.dragLock") as? Bool ?? false
        self.hapticsEnabled = defaults.object(forKey: "kamihi.desktop.hapticsEnabled") as? Bool ?? true

        if let savedStyle = defaults.string(forKey: "kamihi.desktop.cursorStyle"),
           let style = CursorStyle(rawValue: savedStyle) {
            self.cursorStyle = style
        } else {
            // A conventional high-contrast arrow is easier to acquire on a plain
            // black 1080p desktop than the compact dot. Users can still choose the
            // Kamihi Dot, Precision or Large Accessibility styles in settings.
            self.cursorStyle = .classicArrow
        }

        if pointerTuningVersion < 3 {
            defaults.set(3, forKey: "kamihi.desktop.pointerTuningVersion")
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
