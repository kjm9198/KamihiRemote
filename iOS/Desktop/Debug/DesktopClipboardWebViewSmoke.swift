import Foundation
import OSLog
import WebKit

#if DEBUG
@MainActor
enum DesktopClipboardWebViewSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "ClipboardWebViewSmoke")
    static let successMarker = "KAMIHI_CLIPBOARD_WEBVIEW_OK"

    @discardableResult
    static func run(on desktop: DesktopSession) async -> Bool {
        guard ProcessInfo.processInfo.arguments.contains(DesktopClipboardLifecycleSmoke.launchArgument) else { return true }

        // Keep this test deterministic and credential-free. A local HTML fixture
        // exercises the exact DesktopWebInputRegistry path used by Browser,
        // ChatGPT and YouTube without depending on network state or live sites.
        for title in ["Clipboard", "Browser"] {
            for window in desktop.windows.filter({ $0.title == title }) {
                desktop.close(window.id)
            }
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        DesktopWebInputRegistry.shared.register(webView, key: "Browser")
        defer {
            DesktopWebInputRegistry.shared.unregister(webView)
        }

        webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
              <body>
                <textarea id="editor" aria-label="Kamihi Clipboard WebView editor"></textarea>
                <script>
                  const editor = document.getElementById('editor');
                  editor.addEventListener('input', () => {
                    document.title = 'VALUE:' + editor.value;
                  });
                  editor.focus();
                  document.title = 'READY';
                </script>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://kamihi.local")
        )

        guard await waitForTitle("READY", in: webView) else {
            return fail("fixture", "Local editable WebView fixture never became ready")
        }

        let browserID = desktop.openProductivityApp(
            "Browser",
            frame: CGRect(x: 0.07, y: 0.09, width: 0.64, height: 0.72)
        )
        let clipboardID = desktop.openProductivityApp(
            "Clipboard",
            frame: CGRect(x: 0.42, y: 0.14, width: 0.50, height: 0.64)
        )

        guard desktop.activeWindowID == clipboardID,
              desktop.clipboardPasteDestination?.id == browserID else {
            return fail("ownership", "Clipboard did not resolve the immediately-adjacent Browser window")
        }

        let payload = "Kamihi WebView paste once"
        guard desktop.pasteClipboardItemIntoPreviousApp(payload) else {
            return fail("route", "Clipboard rejected the supported Browser destination")
        }
        guard desktop.activeWindowID == browserID else {
            return fail("focus", "Clipboard paste did not transfer frontmost focus to Browser")
        }
        guard await waitForTitle("VALUE:\(payload)", in: webView) else {
            return fail("insert", "Focused WebView editor did not receive exactly one Clipboard insertion")
        }

        logger.notice("\(successMarker, privacy: .public)")
        print(successMarker)
        return true
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

    private static func fail(_ step: String, _ message: String) -> Bool {
        let diagnostic = "KAMIHI_CLIPBOARD_WEBVIEW_FAIL [\(step)] \(message)"
        logger.error("\(diagnostic, privacy: .public)")
        print(diagnostic)
        return false
    }
}
#endif
