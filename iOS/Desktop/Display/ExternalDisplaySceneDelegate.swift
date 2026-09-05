import SwiftUI
import UIKit

/// The one persistent desktop is restored only once per process launch. Keeping
/// this state outside the scene delegate matters because iOS may destroy and
/// recreate the external-display scene when USB-C glasses/monitors are unplugged
/// and reattached while the Kamihi process remains alive.
@MainActor
private var hasRestoredInitialPersistentDesktop = false

/// Track every external-display scene iOS currently considers connected. During
/// a fast USB-C unplug/replug iOS can briefly overlap the retiring scene and its
/// replacement. Without scene ownership, a late `sceneDidDisconnect` from the old
/// scene can incorrectly mark the whole desktop disconnected after the new scene
/// is already live. The set makes disconnect a last-scene-only transition.
@MainActor
private var activeExternalDisplaySceneIDs: Set<String> = []

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
        let sceneLogicalSize = windowScene.coordinateSpace.bounds.size
        let root = ExternalDesktopCanvasView()
            .environmentObject(DesktopSession.shared)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .black
        controller.view.isOpaque = true
        // Keep SwiftUI/UIKit rendering aligned with the backing scale iOS negotiated for the external display.
        controller.view.contentScaleFactor = max(screen.nativeScale, 1)

        let window = UIWindow(windowScene: windowScene)
        // Size the window from the scene coordinate space rather than assuming UIScreen.bounds
        // is the final logical canvas. This follows the exact geometry iOS exposes to this scene
        // when an adapter/display negotiates a mode or reapplies overscan compensation.
        window.frame = windowScene.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        DesktopCaptureService.shared.attach(externalWindow: window)

        Task { @MainActor in
            activeExternalDisplaySceneIDs.insert(session.persistentIdentifier)
            ExternalDisplayCoordinator.shared.connect(screen: screen, logicalSize: sceneLogicalSize)

            // The normal product is one persistent desktop. On the first external
            // connection of this app process, restore the saved desktop directly.
            // Do not consult Clean/Resume/Work/Browse/Media/Vibe compatibility
            // identifiers: an old persisted profile must never seed or rearrange
            // the user's current desktop. No snapshot means a genuinely empty
            // black desktop. USB-C reconnects during the same process keep the
            // current in-memory windows and therefore do not replay restoration.
            if !hasRestoredInitialPersistentDesktop {
                hasRestoredInitialPersistentDesktop = true
                if !DesktopFeatureState.shared.restoreSession(desktop: DesktopSession.shared) {
                    DesktopSession.shared.closeAllDesktopWindows()
                }
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        applyNegotiatedGeometry(from: windowScene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        applyNegotiatedGeometry(from: windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        DesktopCaptureService.shared.detach(externalWindow: window)
        let disconnectedSceneID = scene.session.persistentIdentifier
        Task { @MainActor in
            // Always preserve current windows, but only tell the shared desktop it
            // disconnected when this was the last live external scene. This avoids
            // a stale retiring scene tearing down controller state for a replacement
            // scene that iOS already connected during a quick cable replug.
            DesktopFeatureState.shared.saveSession(desktop: DesktopSession.shared)
            activeExternalDisplaySceneIDs.remove(disconnectedSceneID)
            if activeExternalDisplaySceneIDs.isEmpty {
                ExternalDisplayCoordinator.shared.disconnect()
            }
        }
        window = nil
    }

    private func applyNegotiatedGeometry(from windowScene: UIWindowScene) {
        let screen = windowScene.screen
        let sceneBounds = windowScene.coordinateSpace.bounds
        window?.frame = sceneBounds
        window?.rootViewController?.view.contentScaleFactor = max(screen.nativeScale, 1)
        Task { @MainActor in
            ExternalDisplayCoordinator.shared.refreshMetrics(from: screen, logicalSize: sceneBounds.size)
        }
    }
}