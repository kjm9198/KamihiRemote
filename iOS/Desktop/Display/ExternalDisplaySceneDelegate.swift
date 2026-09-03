import SwiftUI
import UIKit

/// Startup profiles are a one-time process launch decision, not a cable-reconnect
/// policy. Keeping this state outside the scene delegate matters because iOS may
/// destroy and recreate the external-display scene when USB-C glasses/monitors are
/// unplugged and reattached while the Kamihi process remains alive.
@MainActor
private var hasAppliedInitialDesktopLaunchProfile = false

/// User-initiated capture bridge for the Kamihi-owned external-display scene.
///
/// This snapshots only Kamihi's external UIWindow, at the backing scale iOS
/// negotiated for that screen, then presents the standard iOS share sheet from
/// the foreground phone scene. It never captures the normal iPhone screen,
/// saves to Photos automatically, or requests broad photo-library access.
@MainActor
final class DesktopCaptureService {
    static let shared = DesktopCaptureService()

    private weak var externalWindow: UIWindow?

    private init() {}

    func attach(externalWindow: UIWindow) {
        self.externalWindow = externalWindow
    }

    func detach(externalWindow: UIWindow?) {
        guard self.externalWindow === externalWindow else { return }
        self.externalWindow = nil
    }

    @discardableResult
    func captureAndShare() -> Bool {
        guard let image = captureExternalDesktop(),
              let presenter = phonePresenter() else {
            return false
        }

        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
        return true
    }

    private func captureExternalDesktop() -> UIImage? {
        guard let window = externalWindow,
              window.bounds.width > 0,
              window.bounds.height > 0 else {
            return nil
        }

        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(window.screen.nativeScale, 1)
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { context in
            // drawHierarchy preserves SwiftUI/WebKit visual composition when available.
            // Fall back to CALayer rendering for deterministic native surfaces.
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) {
                window.layer.render(in: context.cgContext)
            }
        }
    }

    private func phonePresenter() -> UIViewController? {
        let phoneScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first {
                $0.activationState == .foregroundActive &&
                $0.session.role == .windowApplication
            }

        guard let root = phoneScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? phoneScene?.windows.first(where: { !$0.isHidden })?.rootViewController else {
            return nil
        }

        return topPresenter(from: root)
    }

    private func topPresenter(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topPresenter(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topPresenter(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topPresenter(from: selected)
        }
        return controller
    }
}

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
        DesktopCaptureService.shared.attach(externalWindow: window)

        Task { @MainActor in
            ExternalDisplayCoordinator.shared.connect(screen: screen)

            // Apply Clean/Resume/Work/Browse/Media/Vibe only for the first
            // external-display connection of this app process. A USB-C unplug /
            // reconnect must retain the current windows, workspace and active app
            // instead of re-running the startup profile over the live session.
            if !hasAppliedInitialDesktopLaunchProfile {
                hasAppliedInitialDesktopLaunchProfile = true
                DesktopLaunchProfile.selected.apply(to: DesktopSession.shared)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        let screen = windowScene.screen
        window?.frame = screen.bounds
        window?.rootViewController?.view.contentScaleFactor = screen.nativeScale
        Task { @MainActor in
            ExternalDisplayCoordinator.shared.refreshMetrics(from: screen)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        DesktopCaptureService.shared.detach(externalWindow: window)
        Task { @MainActor in
            DesktopFeatureState.shared.saveSession(desktop: DesktopSession.shared)
            ExternalDisplayCoordinator.shared.disconnect()
        }
        window = nil
    }
}
