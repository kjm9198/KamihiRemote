import Foundation
import OSLog
import WebKit

#if DEBUG
@MainActor
enum DesktopChatGPTLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")
    private static let markerURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("kamihi-chatgpt-lifecycle-smoke.txt", isDirectory: false)

    @discardableResult
    static func run(desktop: DesktopSession = .shared) async -> Bool {
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
    /// a non-persistent website store. This proves focus -> type -> delete -> type
    /// -> normal Enter/send without relying on the live ChatGPT service or auth.
    private static func verifyRoutedComposerInput() async -> Bool {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            configuration: configuration
        )
        defer {
            DesktopWebInputRegistry.shared.unregister(webView)
            webView.stopLoading()
        }

        webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
              <body>
                <form id="composer-form" data-testid="composer">
                  <div id="composer" role="textbox" contenteditable="true" aria-label="Prompt"></div>
                  <button id="send" data-testid="send-button" type="submit">Send</button>
                </form>
                <script>
                  const composer = document.getElementById('composer');
                  const form = document.getElementById('composer-form');
                  composer.addEventListener('input', () => {
                    document.title = 'VALUE:' + composer.textContent;
                  });
                  form.addEventListener('submit', event => {
                    event.preventDefault();
                    document.title = 'SENT:' + composer.textContent;
                  });
                  composer.focus();
                  document.title = 'READY';
                </script>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://kamihi-chatgpt.local")
        )

        guard await waitForTitle("READY", in: webView) else {
            return fail("composer-fixture")
        }
        guard await focusComposer(in: webView) else {
            return fail("composer-focus")
        }

        DesktopWebInputRegistry.shared.register(webView, key: "ChatGPT")
        DesktopWebInputRegistry.shared.type(key: "ChatGPT", text: "hello")
        guard await waitForTitle("VALUE:hello", in: webView) else {
            return fail("composer-type")
        }

        DesktopWebInputRegistry.shared.deleteBackward(key: "ChatGPT")
        guard await waitForTitle("VALUE:hell", in: webView) else {
            return fail("composer-delete")
        }

        DesktopWebInputRegistry.shared.type(key: "ChatGPT", text: "o")
        guard await waitForTitle("VALUE:hello", in: webView) else {
            return fail("composer-retype")
        }

        DesktopWebInputRegistry.shared.pressEnter(key: "ChatGPT")
        guard await waitForTitle("SENT:hello", in: webView) else {
            return fail("composer-enter-send")
        }

        return true
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
