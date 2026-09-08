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

        // This smoke runs immediately before the rendered-pointer smoke in the
        // same process. Require the Clipboard SwiftUI view to actually appear so
        // its later teardown can be observed; otherwise a delayed onDisappear
        // from this fixture can clear the next Clipboard view's shared hit registry.
        guard await waitForClipboardViewAppearance() else {
            return fail("clipboard-render", "Clipboard view never registered its rendered controls")
        }

        guard desktop.activeWindowID == clipboardID,
              desktop.clipboardPasteDestination?.id == browserID else {
            return fail("ownership", "Clipboard did not resolve the immediately-adjacent Browser window")
        }

        // Opening the real Browser window also creates/registers its production
        // WKWebView under the "Browser" key. The local fixture must own that key
        // only for the exact insertion under test; otherwise the smoke can route
        // into the real Browser renderer and falsely report that the clipboard
        // bridge failed. Focus the local editor first, then register and paste
        // without any suspension between those two operations.
        guard await focusEditor(in: webView) else {
            return fail("focus-fixture", "Local WebView editor could not become the active element")
        }
        DesktopWebInputRegistry.shared.register(webView, key: "Browser")

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

        // Leave the next smoke a genuinely clean lifecycle boundary. Closing the
        // model windows is synchronous, while SwiftUI onDisappear is not, so wait
        // for the Clipboard hit registry/callback to be released instead of using
        // an arbitrary sleep or letting teardown race the next reopen.
        desktop.close(clipboardID)
        desktop.close(browserID)
        guard await waitForClipboardViewTeardown() else {
            return fail("cleanup", "Clipboard view did not release its rendered hit registry after close")
        }

        logger.notice("\(successMarker, privacy: .public)")
        print(successMarker)
        return true
    }

    private static func focusEditor(in webView: WKWebView) async -> Bool {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(
                """
                (() => {
                  const editor = document.getElementById('editor');
                  if (!editor || editor.disabled || editor.readOnly) return false;
                  editor.focus();
                  return document.activeElement === editor;
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

    private static func waitForClipboardViewAppearance(attempts: Int = 50) async -> Bool {
        for _ in 0..<attempts {
            if DesktopClipboardHitRegistry.shared.entries.contains(where: { $0.target == .toolbarRefresh }),
               DesktopClipboardHitRegistry.shared.onClearRequested != nil {
                return true
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func waitForClipboardViewTeardown(attempts: Int = 50) async -> Bool {
        for _ in 0..<attempts {
            if DesktopClipboardHitRegistry.shared.entries.isEmpty,
               DesktopClipboardHitRegistry.shared.onClearRequested == nil {
                return true
            }
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
