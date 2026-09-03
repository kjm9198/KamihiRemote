import SwiftUI
import UIKit

/// Coordinates external display native pixel geometry, refresh capability, calibration, and reconnection.
/// Connection/disconnection ownership lives in `ExternalDisplaySceneDelegate`, which is the modern
/// scene-based lifecycle path for external displays. This coordinator only tracks metrics/state.
@MainActor
public final class ExternalDisplayCoordinator: ObservableObject {
    public static let shared = ExternalDisplayCoordinator()

    private enum DefaultsKey {
        static let horizontalSafeMargin = "kamihi.desktop.display.horizontalSafeMargin"
        static let verticalSafeMargin = "kamihi.desktop.display.verticalSafeMargin"
        static let leftSafeTrim = "kamihi.desktop.display.leftSafeTrim"
        static let rightSafeTrim = "kamihi.desktop.display.rightSafeTrim"
        static let topSafeTrim = "kamihi.desktop.display.topSafeTrim"
        static let bottomSafeTrim = "kamihi.desktop.display.bottomSafeTrim"
    }

    @Published public private(set) var isConnected: Bool = false
    /// Logical UIKit coordinate size used by the scene.
    @Published public private(set) var logicalSize: CGSize = CGSize(width: 1920, height: 1080)
    /// Native backing pixel dimensions reported by iOS for the connected screen.
    @Published public private(set) var nativePixelSize: CGSize = CGSize(width: 1920, height: 1080)
    @Published public private(set) var nativeScale: CGFloat = 1
    @Published public private(set) var maximumFramesPerSecond: Int = 60
    @Published public private(set) var displayName: String = "External Display"
    @Published public private(set) var metricsRevision: Int = 0

    /// Fraction of the desktop width reserved on each left/right edge.
    /// This is an app-level comfort/calibration margin; it does not alter the mode negotiated by iOS.
    @Published public var horizontalSafeMargin: Double {
        didSet {
            horizontalSafeMargin = min(max(horizontalSafeMargin, 0), 0.08)
            UserDefaults.standard.set(horizontalSafeMargin, forKey: DefaultsKey.horizontalSafeMargin)
        }
    }

    /// Fraction of the desktop height reserved on each top/bottom edge.
    @Published public var verticalSafeMargin: Double {
        didSet {
            verticalSafeMargin = min(max(verticalSafeMargin, 0), 0.08)
            UserDefaults.standard.set(verticalSafeMargin, forKey: DefaultsKey.verticalSafeMargin)
        }
    }

    /// Per-edge fine trims let glasses/adapter combinations compensate for asymmetric cropping
    /// without throwing away the simple symmetric baseline. Each trim is intentionally small and
    /// the final effective margin is always clamped to the same safe 0...8% range.
    @Published public var leftSafeTrim: Double {
        didSet {
            leftSafeTrim = min(max(leftSafeTrim, -0.04), 0.04)
            UserDefaults.standard.set(leftSafeTrim, forKey: DefaultsKey.leftSafeTrim)
        }
    }

    @Published public var rightSafeTrim: Double {
        didSet {
            rightSafeTrim = min(max(rightSafeTrim, -0.04), 0.04)
            UserDefaults.standard.set(rightSafeTrim, forKey: DefaultsKey.rightSafeTrim)
        }
    }

    @Published public var topSafeTrim: Double {
        didSet {
            topSafeTrim = min(max(topSafeTrim, -0.04), 0.04)
            UserDefaults.standard.set(topSafeTrim, forKey: DefaultsKey.topSafeTrim)
        }
    }

    @Published public var bottomSafeTrim: Double {
        didSet {
            bottomSafeTrim = min(max(bottomSafeTrim, -0.04), 0.04)
            UserDefaults.standard.set(bottomSafeTrim, forKey: DefaultsKey.bottomSafeTrim)
        }
    }

    /// Backward-compatible display size. Prefer nativePixelSize for diagnostics and logicalSize for layout.
    public var displaySize: CGSize { nativePixelSize }

    /// Orientation-independent native pixel size. RayNeo is normally landscape, but diagnostics should
    /// not incorrectly report a mode mismatch if UIKit momentarily reports swapped dimensions.
    public var landscapeNativePixelSize: CGSize {
        CGSize(
            width: max(nativePixelSize.width, nativePixelSize.height),
            height: min(nativePixelSize.width, nativePixelSize.height)
        )
    }

    public var aspectRatio: CGFloat {
        guard landscapeNativePixelSize.height > 0 else { return 16.0 / 9.0 }
        return landscapeNativePixelSize.width / landscapeNativePixelSize.height
    }

    public var isSixteenNineClass: Bool {
        abs(aspectRatio - (16.0 / 9.0)) < 0.03
    }

    public var isFullHDClass: Bool {
        landscapeNativePixelSize.width >= 1920 && landscapeNativePixelSize.height >= 1080
    }

    /// RayNeo Air 4 Pro's normal 2D target is a 16:9 Full-HD-class input. This is deliberately
    /// capability-based rather than device-name-based because iOS does not provide a reliable model name.
    public var isLikelyRayNeo2DTarget: Bool {
        isFullHDClass && isSixteenNineClass
    }

    /// Effective backing ratios derived from the exact logical canvas and native backing dimensions.
    /// Keeping these visible makes it possible to detect accidental app-side downscaling without
    /// pretending Kamihi can choose a hardware mode that iOS did not negotiate.
    public var effectiveBackingScaleX: CGFloat {
        guard logicalSize.width > 0 else { return nativeScale }
        return nativePixelSize.width / logicalSize.width
    }

    public var effectiveBackingScaleY: CGFloat {
        guard logicalSize.height > 0 else { return nativeScale }
        return nativePixelSize.height / logicalSize.height
    }

    public var isNativeBackingAligned: Bool {
        let tolerance: CGFloat = 0.03
        return abs(effectiveBackingScaleX - nativeScale) <= tolerance
            && abs(effectiveBackingScaleY - nativeScale) <= tolerance
    }

    public var capabilitySummary: String {
        "\(Int(nativePixelSize.width))×\(Int(nativePixelSize.height)) • up to \(maximumFramesPerSecond) Hz"
    }

    public var scaleSummary: String {
        String(format: "logical %.0f×%.0f • %.2fx UIKit scale", logicalSize.width, logicalSize.height, nativeScale)
    }

    public var backingSummary: String {
        String(
            format: "effective %.2fx × %.2fx • %@",
            effectiveBackingScaleX,
            effectiveBackingScaleY,
            isNativeBackingAligned ? "native-aligned" : "inspect scaling"
        )
    }

    public var negotiatedModeSummary: String {
        if isLikelyRayNeo2DTarget && isNativeBackingAligned {
            return "1080p-class 16:9 native backing detected"
        }
        if !isSixteenNineClass {
            return "Negotiated output is not 16:9"
        }
        if !isFullHDClass {
            return "Negotiated output is below 1080p class"
        }
        return "1080p-class output detected; backing scale needs inspection"
    }

    public var effectiveLeftSafeMargin: Double { effectiveMargin(base: horizontalSafeMargin, trim: leftSafeTrim) }
    public var effectiveRightSafeMargin: Double { effectiveMargin(base: horizontalSafeMargin, trim: rightSafeTrim) }
    public var effectiveTopSafeMargin: Double { effectiveMargin(base: verticalSafeMargin, trim: topSafeTrim) }
    public var effectiveBottomSafeMargin: Double { effectiveMargin(base: verticalSafeMargin, trim: bottomSafeTrim) }

    public var hasAsymmetricCalibration: Bool {
        abs(leftSafeTrim) > 0.0001
            || abs(rightSafeTrim) > 0.0001
            || abs(topSafeTrim) > 0.0001
            || abs(bottomSafeTrim) > 0.0001
    }

    public var hasCalibration: Bool {
        horizontalSafeMargin > 0
            || verticalSafeMargin > 0
            || hasAsymmetricCalibration
    }

    public var calibrationSummary: String {
        if hasAsymmetricCalibration {
            let left = Int((effectiveLeftSafeMargin * 100).rounded())
            let right = Int((effectiveRightSafeMargin * 100).rounded())
            let top = Int((effectiveTopSafeMargin * 100).rounded())
            let bottom = Int((effectiveBottomSafeMargin * 100).rounded())
            return "Safe L \(left)% • R \(right)% • T \(top)% • B \(bottom)%"
        }

        let h = Int((horizontalSafeMargin * 100).rounded())
        let v = Int((verticalSafeMargin * 100).rounded())
        return h == 0 && v == 0 ? "Full canvas" : "Safe margins H \(h)% • V \(v)%"
    }

    private init() {
        horizontalSafeMargin = min(max(UserDefaults.standard.double(forKey: DefaultsKey.horizontalSafeMargin), 0), 0.08)
        verticalSafeMargin = min(max(UserDefaults.standard.double(forKey: DefaultsKey.verticalSafeMargin), 0), 0.08)
        leftSafeTrim = min(max(UserDefaults.standard.double(forKey: DefaultsKey.leftSafeTrim), -0.04), 0.04)
        rightSafeTrim = min(max(UserDefaults.standard.double(forKey: DefaultsKey.rightSafeTrim), -0.04), 0.04)
        topSafeTrim = min(max(UserDefaults.standard.double(forKey: DefaultsKey.topSafeTrim), -0.04), 0.04)
        bottomSafeTrim = min(max(UserDefaults.standard.double(forKey: DefaultsKey.bottomSafeTrim), -0.04), 0.04)
    }

    /// Called by the active external-display scene delegate when iOS creates the display scene.
    public func connect(screen: UIScreen) {
        let wasConnected = isConnected
        isConnected = true
        refreshMetrics(from: screen)

        if !wasConnected {
            DesktopSession.shared.externalDisplayDidConnect()
        }
    }

    /// Refresh metrics after an already-connected display changes mode/geometry.
    /// Identical UIKit scene updates are intentionally ignored so a 1080p external canvas does not
    /// invalidate multiple SwiftUI surfaces when the negotiated display metrics have not changed.
    public func refreshMetrics(from screen: UIScreen) {
        let newLogicalSize = screen.bounds.size
        let newNativePixelSize = screen.nativeBounds.size
        let newNativeScale = screen.nativeScale
        let newMaximumFramesPerSecond = screen.maximumFramesPerSecond
        let newDisplayName = "External Display • \(Int(newNativePixelSize.width))×\(Int(newNativePixelSize.height))"

        guard logicalSize != newLogicalSize
            || nativePixelSize != newNativePixelSize
            || abs(nativeScale - newNativeScale) > 0.0001
            || maximumFramesPerSecond != newMaximumFramesPerSecond
            || displayName != newDisplayName else {
            return
        }

        logicalSize = newLogicalSize
        nativePixelSize = newNativePixelSize
        nativeScale = newNativeScale
        maximumFramesPerSecond = newMaximumFramesPerSecond
        displayName = newDisplayName
        metricsRevision &+= 1
    }

    /// Called by the active external-display scene delegate when iOS tears down the display scene.
    public func disconnect() {
        guard isConnected else { return }
        isConnected = false
        DesktopSession.shared.externalDisplayDidDisconnect()
    }

    public func resetCalibration() {
        horizontalSafeMargin = 0
        verticalSafeMargin = 0
        leftSafeTrim = 0
        rightSafeTrim = 0
        topSafeTrim = 0
        bottomSafeTrim = 0
    }

    public func safeInsets(for size: CGSize) -> EdgeInsets {
        EdgeInsets(
            top: size.height * CGFloat(effectiveTopSafeMargin),
            leading: size.width * CGFloat(effectiveLeftSafeMargin),
            bottom: size.height * CGFloat(effectiveBottomSafeMargin),
            trailing: size.width * CGFloat(effectiveRightSafeMargin)
        )
    }

    private func effectiveMargin(base: Double, trim: Double) -> Double {
        min(max(base + trim, 0), 0.08)
    }
}
