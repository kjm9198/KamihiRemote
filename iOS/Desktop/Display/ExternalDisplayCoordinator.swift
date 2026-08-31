import SwiftUI
import UIKit

/// Coordinates external display discovery, screen geometry, and display reconnection.
@MainActor
public final class ExternalDisplayCoordinator: ObservableObject {
    public static let shared = ExternalDisplayCoordinator()

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var displaySize: CGSize = CGSize(width: 1920, height: 1080)
    @Published public private(set) var displayName: String = "External Display"

    private init() {
        checkConnectedScreens()
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkConnectedScreens()
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkConnectedScreens()
        }
    }

    public func checkConnectedScreens() {
        let screens = UIScreen.screens
        if screens.count > 1, let external = screens.last {
            isConnected = true
            displaySize = external.bounds.size
            displayName = "External Screen (\(Int(displaySize.width))x\(Int(displaySize.height)))"
            DesktopSession.shared.externalDisplayDidConnect()
        } else {
            isConnected = false
            DesktopSession.shared.externalDisplayDidDisconnect()
        }
    }
}
