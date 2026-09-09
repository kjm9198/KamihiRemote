import Foundation
import OSLog
import UIKit
import WebKit

#if DEBUG
@MainActor
enum DesktopChatGPTLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")
    private static let markerURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("kamihi-chatgpt-lifecycle-smoke.txt", isDirectory: false)

    private final class FixtureNavigationWaiter: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?

        func loadHTML(_ html: String, baseURL: URL?, in webView: WKWebView) async -> Bool {
            webView.navigationDelegate = self
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(true)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(false)
        }

        private func finish(_ succeeded: Bool) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: succeeded)
        }
    }

    @discardableResult
    static func run(desktop providedDesktop: DesktopSession? = nil) async -> Bool {
        let desktop = providedDesktop ?? DesktopSession.shared
        try? FileManager.default.removeItem(at: markerURL)

        let originalWindows = desktop.windows
        let originalActiveID = desktop.activeWindowID
        let originalKeyboardRequest = desktop.wantsPhoneKeyboard

        defer {
            desktop.windows = originalWindows
            desktop.activeWindowID = originalActiveID
            desktop.wantsPhoneKeyboard = originalKeyboardRequest
        }

        desktop.windows = originalWindows.filter { $0.title != "ChatGPT" }
        if desktop.activeWindowID.flatMap({ id in desktop.windows.contains(where: { $0.id == id }) }) != true {
            desktop.activeWindowID = desktop.windows.last(where: { !$0.isMinimized })?.id
        }

        let firstID = desktop.openProductivityApp(
            "ChatGPT",
            frame: CGRect(x: 0.14, y: 0.10, width: 0.68, height: 0.70)
        )
        guard let opened = desktop.windows.first(where: { $0.id == firstID }),
              opened.title == "ChatGPT",
              !opened.isMinimized,
              desktop.activeWindowID == firstID else {
            return fail("open")
        }

        desktop.minimize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMinimized == true,
              desktop.activeWindowID != firstID else {
            return fail("minimize")
        }

        let restoredID = desktop.openProductivityApp("ChatGPT")
        guard restoredID == firstID,
              desktop.activeWindowID == firstID,
              desktop.windows.first(where: { $0.id == firstID })?.isMinimized == false else {
            return fail("restore")
        }

        desktop.toggleMaximize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMaximized == true,
              desktop.activeWindowID == firstID else {
            return fail("maximize")
        }

        desktop.toggleMaximize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMaximized == false else {
            return fail("restore-size")
        }

        desktop.close(firstID)
        guard !desktop.windows.contains(where: { $0.id == firstID }),
              desktop.activeWindowID != firstID else {
            return fail("close")
        }

        let reopenedID = desktop.openProductivityApp("ChatGPT")
        guard reopenedID != firstID,
              desktop.activeWindowID == reopenedID,
              desktop.windows.first(where: { $0.id == reopenedID })?.title == "ChatGPT" else {
            return fail("reopen")
        }

        desktop.close(reopenedID)
        guard !desktop.windows.contains(where: { $0.id == reopenedID }) else {
            return fail("final-close")
        }

        guard await verifyRoutedComposerInput() else { return false }

        emit("KAMIHI_CHATGPT_LIFECYCLE_OK")
        return true
    }

    /// Network-free WebKit fixture for the exact shared input bridge used by the
    /// ChatGPT window. It intentionally contains no account/session data and uses
    /// a non-persistent website store. Attach the WebView to a real UIWindowScene
    /// so WebKit gets rendered process lifecycle rather than a detached test view.
    /// The app-level DEBUG harness can start before SwiftUI finishes scene hookup,
    /// so wait a short bounded interval for UIKit to publish the scene instead of
    /// failing before the product UI has had a chance to connect.
    private static func verifyRoutedComposerInput() async -> Bool {
        guard let scene = await waitForWindowScene() else {
            return fail("composer-scene")
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            configuration: configuration
        )
        let hostController = UIViewController()
        hostController.view.backgroundColor = .systemBackground
        webView.frame = hostController.view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostController.view.addSubview(webView)

        let hostWindow = UIWindow(windowScene: scene)
        hostWindow.frame = scene.effectiveGeometry.coordinateSpace.bounds
        hostWindow.rootViewController = hostController
        hostWindow.windowLevel = .normal
        hostWindow.isHidden = false

        let navigationWaiter = FixtureNavigationWaiter()
        defer {
            DesktopWebInputRegistry.shared.unregister(webView)
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.removeFromSuperview()
            hostWindow.isHidden = true
            hostWindow.rootViewController = nil
        }

        let html = """
        <!doctype html>
        <html>
          <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
          <body>
            <div id="composer-shell" data-testid="composer">
              <div id="composer" role="textbox" contenteditable="true" aria-label="Prompt"></div>
              <button id="send" data-testid="send-button" type="button">Send</button>
            </div>
            <script>
              const composer = document.getElementById('composer');
              const send = document.getElementById('send');
              composer.addEventListener('input', () => {
                document.title = 'VALUE:' + composer.textContent;
              });
              send.addEventListener('click', event => {
                event.preventDefault();
                document.documentElement.dataset.kamihiSent = composer.textContent;
                document.title = 'SENT:' + composer.textContent;
              });
              composer.focus();
              document.title = 'READY';
            </script>
          </body>
        </html>
        """

        guard await navigationWaiter.loadHTML(
            html,
            baseURL: URL(string: "https://kamihi-chatgpt.local"),
            in: webView
        ) else {
            return fail("composer-navigation")
        }

        let fixtureReady: Bool
        if webView.title == "READY" {
            fixtureReady = true
        } else {
            fixtureReady = await waitForTitle("READY", in: webView)
        }
        guard fixtureReady else {
            return fail("composer-fixture")
        }
        guard await focusComposer(in: webView) else {
            return fail("composer-focus")
        }

        // The lifecycle portion above intentionally creates and destroys the real
        // ChatGPT SwiftUI WebView. Its representable can finish an asynchronous
        // update/dismantle while this isolated fixture is running, and both use the
        // production registry key. Re-bind the exact fixture immediately before
        // every routed command so a delayed real-view callback cannot redirect a
        // test operation to a stale WebView. The command implementation itself is
        // unchanged and remains the same route used by phone/hardware input.
        bindFixture(webView)
        DesktopWebInputRegistry.shared.type(key: "ChatGPT", text: "hello")
        guard await waitForTitle("VALUE:hello", in: webView) else {
            return fail("composer-type")
        }

        bindFixture(webView)
        DesktopWebInputRegistry.shared.deleteBackward(key: "ChatGPT")
        guard await waitForTitle("VALUE:hell", in: webView) else {
            return fail("composer-delete")
        }

        bindFixture(webView)
        DesktopWebInputRegistry.shared.type(key: "ChatGPT", text: "o")
        guard await waitForTitle("VALUE:hello", in: webView) else {
            return fail("composer-retype")
        }

        bindFixture(webView)
        DesktopWebInputRegistry.shared.pressEnter(key: "ChatGPT")
        // The routed send is a DOM action. Assert the click handler's live DOM
        // state directly rather than relying solely on WKWebView.title KVO, which
        // can lag independently of JavaScript execution on hosted simulators.
        // This remains strict: only the production registry call above can set
        // this value, and the expected composer payload must match exactly.
        guard await waitForSentValue("hello", in: webView) else {
            return fail("composer-enter-send")
        }

        return true
    }

    private static func bindFixture(_ webView: WKWebView) {
        DesktopWebInputRegistry.shared.register(webView, key: "ChatGPT")
    }

    private static func waitForWindowScene(attempts: Int = 50) async -> UIWindowScene? {
        for _ in 0..<attempts {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
                return active
            }
            if let inactive = scenes.first(where: { $0.activationState == .foregroundInactive }) {
                return inactive
            }
            if let connected = scenes.first {
                return connected
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private static func focusComposer(in webView: WKWebView) async -> Bool {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(
                """
                (() => {
                  const composer = document.getElementById('composer');
                  if (!composer) return false;
                  composer.focus();
                  return document.activeElement === composer;
                })();
                """
            ) { result, _ in
                continuation.resume(returning: result as? Bool ?? false)
            }
        }
    }

    private static func waitForTitle(
        _ expected: String,
        in webView: WKWebView,
        attempts: Int = 50
    ) async -> Bool {
        for _ in 0..<attempts {
            if !webView.isLoading, webView.title == expected { return true }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func waitForSentValue(
        _ expected: String,
        in webView: WKWebView,
        attempts: Int = 50
    ) async -> Bool {
        for _ in 0..<attempts {
            let value: String? = await withCheckedContinuation { continuation in
                webView.evaluateJavaScript("document.documentElement.dataset.kamihiSent || ''") { result, _ in
                    continuation.resume(returning: result as? String)
                }
            }
            if value == expected { return true }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func fail(_ step: String) -> Bool {
        emit("KAMIHI_CHATGPT_LIFECYCLE_FAIL [\(step)]")
        return false
    }

    private static func emit(_ marker: String) {
        if marker.hasPrefix("KAMIHI_CHATGPT_LIFECYCLE_FAIL") {
            logger.error("\(marker, privacy: .public)")
        } else {
            logger.notice("\(marker, privacy: .public)")
        }
        print(marker)

        do {
            try Data((marker + "\n").utf8).write(to: markerURL, options: .atomic)
        } catch {
            logger.error("KAMIHI_CHATGPT_LIFECYCLE_MARKER_WRITE_FAIL [\(error.localizedDescription, privacy: .public)]")
            print("KAMIHI_CHATGPT_LIFECYCLE_MARKER_WRITE_FAIL [\(error.localizedDescription)]")
        }
    }
}
#endif