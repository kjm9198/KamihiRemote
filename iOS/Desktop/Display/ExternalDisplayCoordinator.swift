import SwiftUI
import UIKit

/// Coordinates external display discovery, native pixel geometry, refresh capability, calibration, and reconnection.
@MainActor
public final class ExternalDisplayCoordinator: ObservableObject {
    public static let shared = ExternalDisplayCoordinator()

    private enum DefaultsKey {
        static let horizontalSafeMargin = "kamihi.desktop.display.horizontalSafeMargin"
        static let verticalSafeMargin = "kamihi.desktop.display.verticalSafeMargin"
    }

    @Published public private(set) var isConnected: Bool = false
    /// Logical UIKit coordinate size used by the scene.
    @Published public private(set) var logicalSize: CGSize = CGSize(width: 1920, height: 1080)
    /// Native backing pixel dimensions reported by iOS for the connected screen.
    @Published public private(set) var nativePixelSize: CGSize = CGSize(width: 1920, height: 1080)
    @Published public private(set) var nativeScale: CGFloat = 1
    @Published public private(set) var maximumFramesPerSecond: Int = 60
    @Published public private(set) var displayName: String = "External Display"

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

    /// Backward-compatible display size. Prefer nativePixelSize for diagnostics and logicalSize for layout.
    public var displaySize: CGSize { nativePixelSize }

    public var aspectRatio: CGFloat {
        guard nativePixelSize.height > 0 else { return 16.0 / 9.0 }
        return nativePixelSize.width / nativePixelSize.height
    }

    public var isFullHDClass: Bool {
        nativePixelSize.width >= 1920 && nativePixelSize.height >= 1080
    }

    /// RayNeo Air 4 Pro's normal 2D target is a 16:9 Full-HD-class input. This is deliberately
    /// capability-based rather than device-name-based because iOS does not provide a reliable model name.
    public var isLikelyRayNeo2DTarget: Bool {
        let ratioDelta = abs(aspectRatio - (16.0 / 9.0))
        return isFullHDClass && ratioDelta < 0.03
    }

    public var capabilitySummary: String {
        "\(Int(nativePixelSize.width))×\(Int(nativePixelSize.height)) • up to \(maximumFramesPerSecond) Hz"
    }

    public var scaleSummary: String {
        String(format: "logical %.0f×%.0f • %.2fx backing scale", logicalSize.width, logicalSize.height, nativeScale)
    }

    public var calibrationSummary: String {
        let h = Int((horizontalSafeMargin * 100).rounded())
        let v = Int((verticalSafeMargin * 100).rounded())
        return h == 0 && v == 0 ? "Full canvas" : "Safe margins H \(h)% • V \(v)%"
    }

    private init() {
        horizontalSafeMargin = min(max(UserDefaults.standard.double(forKey: DefaultsKey.horizontalSafeMargin), 0), 0.08)
        verticalSafeMargin = min(max(UserDefaults.standard.double(forKey: DefaultsKey.verticalSafeMargin), 0), 0.08)

        checkConnectedScreens()
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else {
                self?.checkConnectedScreens()
                return
            }
            self?.connect(screen: screen)
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkConnectedScreens()
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.modeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else {
                self?.checkConnectedScreens()
                return
            }
            self?.connect(screen: screen, notifySession: false)
        }
    }

    public func connect(screen: UIScreen) {
        connect(screen: screen, notifySession: true)
    }

    private func connect(screen: UIScreen, notifySession: Bool) {
        let wasConnected = isConnected
        isConnected = true
        logicalSize = screen.bounds.size
        nativePixelSize = screen.nativeBounds.size
        nativeScale = screen.nativeScale
        maximumFramesPerSecond = screen.maximumFramesPerSecond
        displayName = "External Display • \(Int(nativePixelSize.width))×\(Int(nativePixelSize.height))"

        if notifySession && !wasConnected {
            DesktopSession.shared.externalDisplayDidConnect()
        }
    }

    public func disconnect() {
        guard isConnected else { return }
        isConnected = false
        DesktopSession.shared.externalDisplayDidDisconnect()
    }

    public func resetCalibration() {
        horizontalSafeMargin = 0
        verticalSafeMargin = 0
    }

    public func safeInsets(for size: CGSize) -> EdgeInsets {
        let horizontal = size.width * CGFloat(horizontalSafeMargin)
        let vertical = size.height * CGFloat(verticalSafeMargin)
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    public func checkConnectedScreens() {
        let screens = UIScreen.screens
        if screens.count > 1, let external = screens.last {
            connect(screen: external, notifySession: !isConnected)
        } else {
            disconnect()
        }
    }
}
