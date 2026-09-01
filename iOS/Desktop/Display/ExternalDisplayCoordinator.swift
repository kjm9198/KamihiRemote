import SwiftUI
import UIKit

/// Coordinates external display discovery, native pixel geometry, refresh capability, and reconnection.
@MainActor
public final class ExternalDisplayCoordinator: ObservableObject {
    public static let shared = ExternalDisplayCoordinator()

    @Published public private(set) var isConnected: Bool = false
    /// Logical UIKit coordinate size used by the scene.
    @Published public private(set) var logicalSize: CGSize = CGSize(width: 1920, height: 1080)
    /// Native backing pixel dimensions reported by iOS for the connected screen.
    @Published public private(set) var nativePixelSize: CGSize = CGSize(width: 1920, height: 1080)
    @Published public private(set) var nativeScale: CGFloat = 1
    @Published public private(set) var maximumFramesPerSecond: Int = 60
    @Published public private(set) var displayName: String = "External Display"

    /// Backward-compatible display size. Prefer nativePixelSize for diagnostics and logicalSize for layout.
    public var displaySize: CGSize { nativePixelSize }

    public var aspectRatio: CGFloat {
        guard nativePixelSize.height > 0 else { return 16.0 / 9.0 }
        return nativePixelSize.width / nativePixelSize.height
    }

    public var isFullHDClass: Bool {
        nativePixelSize.width >= 1920 && nativePixelSize.height >= 1080
    }

    public var capabilitySummary: String {
        "\(Int(nativePixelSize.width))×\(Int(nativePixelSize.height)) • up to \(maximumFramesPerSecond) Hz"
    }

    private init() {
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
    }

    public func connect(screen: UIScreen) {
        isConnected = true
        logicalSize = screen.bounds.size
        nativePixelSize = screen.nativeBounds.size
        nativeScale = screen.nativeScale
        maximumFramesPerSecond = screen.maximumFramesPerSecond
        displayName = "External Display • \(Int(nativePixelSize.width))×\(Int(nativePixelSize.height))"
        DesktopSession.shared.externalDisplayDidConnect()
    }

    public func disconnect() {
        isConnected = false
        DesktopSession.shared.externalDisplayDidDisconnect()
    }

    public func checkConnectedScreens() {
        let screens = UIScreen.screens
        if screens.count > 1, let external = screens.last {
            connect(screen: external)
        } else {
            disconnect()
        }
    }
}
