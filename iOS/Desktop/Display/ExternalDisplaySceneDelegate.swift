import SwiftUI
import UIKit

/// Scene delegate for the non-interactive external display window.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        let screen = windowScene.screen
        let root = ExternalDesktopCanvasView()
            .environmentObject(DesktopSession.shared)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .black
        controller.view.isOpaque = true
        // Keep SwiftUI/UIKit rendering aligned with the backing scale iOS negotiated for the external display.
        controller.view.contentScaleFactor = screen.nativeScale

        let window = UIWindow(windowScene: windowScene)
        window.frame = screen.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            ExternalDisplayCoordinator.shared.connect(screen: screen)
            DesktopLaunchProfile.selected.apply(to: DesktopSession.shared)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task { @MainActor in
            DesktopFeatureState.shared.saveSession(desktop: DesktopSession.shared)
            ExternalDisplayCoordinator.shared.disconnect()
        }
        window = nil
    }
}
