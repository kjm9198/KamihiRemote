import SwiftUI
import UIKit

/// Scene delegate for the non-interactive external display window.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        let root = ExternalDesktopCanvasView()
            .environmentObject(DesktopSession.shared)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            let desktop = DesktopSession.shared
            desktop.externalDisplayDidConnect()
            if !DesktopFeatureState.shared.restoreSession(desktop: desktop) {
                desktop.openVibeWorkspace()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task { @MainActor in
            DesktopFeatureState.shared.saveSession(desktop: DesktopSession.shared)
            DesktopSession.shared.externalDisplayDidDisconnect()
        }
        window = nil
    }
}
