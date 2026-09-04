import SwiftUI
import WebKit

/// Shared input registry for web-backed Kamihi Desktop apps.
///
/// The external display is non-interactive, so pointer, scroll and phone-keyboard
/// input is routed from the iPhone controller into the currently visible WKWebView.
/// WebKit keeps credentials/session state; Kamihi never reads password values.
@MainActor
final class DesktopWebInputRegistry {
    static let shared = DesktopWebInputRegistry()

    private final class WeakWebView {
        weak var value: WKWebView?
        init(_ value: WKWebView) { self.value = value }
    }

    private var webViews: [String: WeakWebView] = [:]

    private init() {}

    func register(_ webView: WKWebView, key: String) {
        pruneReleasedEntries()
        webViews[key] = WeakWebView(webView)
    }

    /// Remove only registrations that still point at this exact WebView. This
    /// avoids a dismantled SwiftUI representable accidentally clearing a newer
    /// replacement registered under the same app key.
    func unregister(_ webView: WKWebView) {
        webViews = webViews.filter { _, holder in
            guard let value = holder.value else { return false }
            return value !== webView
        }
    }

    private func pruneReleasedEntries() {
        webViews = webViews.filter { $0.value.value != nil }
    }

    func click(key: String, x: CGFloat, y: CGFloat, completion: @escaping (Bool) -> Void) {
        guard let webView = webViews[key]?.value else {
            completion(false)
            return
        }

        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const hit = document.elementFromPoint(x, y);
          if (!hit) return false;

          const editable = hit.closest?.('input:not([type="button"]):not([type="submit"]):not([type="checkbox"]):not([type="radio"]), textarea, [contenteditable="true"], [role="textbox"]') || (hit.isContentEditable ? hit : null);
          if (editable && !editable.disabled && !editable.readOnly && editable.focus) {
            editable.focus();
          } else if (hit.focus) {
            hit.focus();
          }

          if (hit.click) hit.click();
          return !!(editable && !editable.disabled && !editable.readOnly);
        })();
        """

        webView.evaluateJavaScript(script) { result, _ in
            let editable = result as? Bool ?? false
            Task { @MainActor in completion(editable) }
        }
    }

    /// `HTMLElement.click()` does not synthesize a DOM `dblclick` when called
    /// twice from the non-interactive external-display bridge. Emit the missing
    /// double-click semantic only after the controller has already delivered the
    /// two normal clicks, preserving ordinary link/button activation while making
    /// desktop web affordances such as word selection and app-specific double-click
    /// handlers behave like a real pointer.
    func doubleClick(key: String, x: CGFloat, y: CGFloat) {
        guard let webView = webViews[key]?.value else { return }
        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const hit = document.elementFromPoint(x, y);
          if (!hit) return false;
          hit.dispatchEvent(new MouseEvent('dblclick', {
            bubbles: true,
            cancelable: true,
            view: window,
            detail: 2,
            clientX: x,
            clientY: y,
            button: 0,
            buttons: 0
          }));
          return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func contextClick(key: String, x: CGFloat, y: CGFloat) {
        guard let webView = webViews[key]?.value else { return }
        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const el = document.elementFromPoint(x, y);
          if (!el) return false;
          el.dispatchEvent(new MouseEvent('contextmenu', {bubbles:true, clientX:x, clientY:y}));
          return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func scroll(key: String, deltaX: CGFloat, deltaY: CGFloat) {
        guard let webView = webViews[key]?.value else { return }
        var offset = webView.scrollView.contentOffset
        offset.x += deltaX
        offset.y += deltaY

        let minX = -webView.scrollView.adjustedContentInset.left
        let minY = -webView.scrollView.adjustedContentInset.top
        let maxX = max(minX, webView.scrollView.contentSize.width - webView.scrollView.bounds.width + webView.scrollView.adjustedContentInset.right)
        let maxY = max(minY, webView.scrollView.contentSize.height - webView.scrollView.bounds.height + webView.scrollView.adjustedContentInset.bottom)
        offset.x = min(max(offset.x, minX), maxX)
        offset.y = min(max(offset.y, minY), maxY)
        webView.scrollView.setContentOffset(offset, animated: false)
    }

    func type(key: String, text: String) {
        guard let webView = webViews[key]?.value,
              let data = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }

        let script = """
        (() => {
          const text = \(json);
          const el = document.activeElement;
          if (!el) return false;
          if (el.isContentEditable) {
            document.execCommand('insertText', false, text);
            el.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:text}));
            return true;
          }
          if ('value' in el && !el.disabled && !el.readOnly) {
            const start = el.selectionStart ?? el.value.length;
            const end = el.selectionEnd ?? start;
            if (el.setRangeText) el.setRangeText(text, start, end, 'end');
            else el.value += text;
            el.dispatchEvent(new Event('input', {bubbles:true}));
            return true;
          }
          return false;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func deleteBackward(key: String) {
        guard let webView = webViews[key]?.value else { return }
        let script = """
        (() => {
          const el = document.activeElement;
          if (!el) return false;
          if (el.isContentEditable) {
            document.execCommand('delete', false, null);
            el.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'deleteContentBackward'}));
            return true;
          }
          if ('value' in el && !el.disabled && !el.readOnly) {
            const start = el.selectionStart ?? el.value.length;
            const end = el.selectionEnd ?? start;
            const from = start === end ? Math.max(0, start - 1) : start;
            if (el.setRangeText) el.setRangeText('', from, end, 'end');
            else if (from < end || from > 0) el.value = el.value.slice(0, from) + el.value.slice(end);
            el.dispatchEvent(new Event('input', {bubbles:true}));
            return true;
          }
          return false;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func pressEnter(key: String) {
        guard let webView = webViews[key]?.value else { return }
        let script = """
        (() => {
          const el = document.activeElement;
          if (!el) return false;

          if (el.tagName === 'TEXTAREA' || el.isContentEditable) {
            if (el.isContentEditable) document.execCommand('insertLineBreak', false, null);
            else {
              const start = el.selectionStart ?? el.value.length;
              const end = el.selectionEnd ?? start;
              el.setRangeText('\n', start, end, 'end');
            }
            el.dispatchEvent(new Event('input', {bubbles:true}));
            return true;
          }

          const options = {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true};
          el.dispatchEvent(new KeyboardEvent('keydown', options));
          el.dispatchEvent(new KeyboardEvent('keypress', options));
          el.dispatchEvent(new KeyboardEvent('keyup', options));
          if (el.form && el.form.requestSubmit) el.form.requestSubmit();
          return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func goBack(key: String) {
        guard let webView = webViews[key]?.value, webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward(key: String) {
        guard let webView = webViews[key]?.value, webView.canGoForward else { return }
        webView.goForward()
    }

    func reload(key: String) {
        webViews[key]?.value?.reload()
    }

    func stop(key: String) {
        webViews[key]?.value?.stopLoading()
    }
}

/// Lightweight compatibility bridge used by the standalone desktop web apps
/// (ChatGPT, YouTube and Phone Takeover). The full Browser app uses its own
/// retained multi-tab controller; these single-page surfaces intentionally keep
/// a simpler lifecycle while sharing the default website data store for login
/// and session continuity.
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL?
    var registryKey: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.allowsBackForwardNavigationGestures = false
        webView.uiDelegate = context.coordinator

        if let registryKey {
            DesktopWebInputRegistry.shared.register(webView, key: registryKey)
        }
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.uiDelegate = context.coordinator
        if let registryKey {
            DesktopWebInputRegistry.shared.register(webView, key: registryKey)
        }
        guard let url, webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Closing/replacing a standalone web app should stop network/media work
        // immediately instead of waiting for WebKit/ARC to eventually tear the
        // renderer down. Persistent cookies/session state stay in the default
        // WKWebsiteDataStore and are not copied or deleted here.
        webView.stopLoading()
        webView.uiDelegate = nil
        DesktopWebInputRegistry.shared.unregister(webView)
        webView.removeFromSuperview()
    }

    final class Coordinator: NSObject, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Standalone Desktop web apps intentionally stay single-window. Sites
            // frequently use target=_blank/window.open for sign-in, help and
            // external links; without a UI delegate WebKit silently drops those
            // navigations. Keep the flow alive in the same retained view so login
            // cookies/session state remain in WebKit's default data store.
            guard navigationAction.targetFrame == nil,
                  let requestURL = navigationAction.request.url else { return nil }
            webView.load(URLRequest(url: requestURL))
            return nil
        }
    }
}
