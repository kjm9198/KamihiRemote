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

    private struct PrimaryClickSample {
        let time: TimeInterval
        let x: CGFloat
        let y: CGFloat
        let count: Int
    }

    private var webViews: [String: WeakWebView] = [:]
    private var lastPrimaryClick: [String: PrimaryClickSample] = [:]

    private init() {}

    func register(_ webView: WKWebView, key: String) {
        pruneReleasedEntries()
        webViews[key] = WeakWebView(webView)
    }

    /// Remove only registrations that still point at this exact WebView. This
    /// avoids a dismantled SwiftUI representable accidentally clearing a newer
    /// replacement registered under the same app key.
    func unregister(_ webView: WKWebView) {
        let removedKeys = webViews.compactMap { key, holder -> String? in
            guard let value = holder.value else { return key }
            return value === webView ? key : nil
        }
        webViews = webViews.filter { _, holder in
            guard let value = holder.value else { return false }
            return value !== webView
        }
        for key in removedKeys {
            lastPrimaryClick.removeValue(forKey: key)
        }
    }

    private func pruneReleasedEntries() {
        let releasedKeys = webViews.compactMap { key, holder in holder.value == nil ? key : nil }
        webViews = webViews.filter { $0.value.value != nil }
        for key in releasedKeys {
            lastPrimaryClick.removeValue(forKey: key)
        }
    }

    func click(key: String, x: CGFloat, y: CGFloat, completion: @escaping (Bool) -> Void) {
        guard let webView = webViews[key]?.value else {
            lastPrimaryClick.removeValue(forKey: key)
            completion(false)
            return
        }

        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let now = Date.timeIntervalSinceReferenceDate
        let previous = lastPrimaryClick[key]
        let clickCount: Int
        if let previous {
            let dt = now - previous.time
            let distance = hypot(safeX - previous.x, safeY - previous.y)
            if dt > 0 && dt <= 0.45 && distance <= 0.035 {
                clickCount = min(previous.count + 1, 3)
            } else {
                clickCount = 1
            }
        } else {
            clickCount = 1
        }

        if clickCount >= 3 {
            lastPrimaryClick.removeValue(forKey: key)
        } else {
            lastPrimaryClick[key] = PrimaryClickSample(time: now, x: safeX, y: safeY, count: clickCount)
        }

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

          const anchor = hit.closest?.('a[href]');
          const interactive = hit.closest?.('a, button, [role="button"], [role="link"], input, select, textarea, video, audio') || hit;

          const eventInit = {
            bubbles: true,
            cancelable: true,
            view: window,
            detail: \(clickCount),
            screenX: x,
            screenY: y,
            clientX: x,
            clientY: y,
            button: 0,
            buttons: 1,
            pointerId: 1,
            pointerType: 'mouse',
            isPrimary: true
          };

          // For anchor links, skip synthetic event dispatch to avoid conflicts
          // with site JS event handlers (e.g. Google search results use event
          // delegation that can swallow synthetic events). Native .click() on
          // the <a> element is the most reliable path for link navigation.
          if (anchor) {
            anchor.click();
          } else {
            hit.dispatchEvent(new PointerEvent('pointerdown', eventInit));
            hit.dispatchEvent(new MouseEvent('mousedown', eventInit));

            const upInit = Object.assign({}, eventInit, { buttons: 0 });
            hit.dispatchEvent(new PointerEvent('pointerup', upInit));
            hit.dispatchEvent(new MouseEvent('mouseup', upInit));
            hit.dispatchEvent(new MouseEvent('click', upInit));

            // For non-link interactive elements (buttons, inputs, etc.),
            // also call native .click() as a reliable fallback.
            if (interactive !== hit && interactive.click && !interactive.closest?.('a[href]')) {
              interactive.click();
            } else if (hit.click && !hit.closest?.('a[href]')) {
              hit.click();
            }
          }

          const count = \(clickCount);
          if (count === 2) {
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

            try {
              if (editable && ('selectionStart' in editable)) {
                const val = editable.value || '';
                const pos = editable.selectionStart ?? 0;
                let start = pos;
                while (start > 0 && !/\\s/.test(val[start - 1])) start--;
                let end = pos;
                while (end < val.length && !/\\s/.test(val[end])) end++;
                if (start < end && editable.setSelectionRange) {
                  editable.setSelectionRange(start, end);
                }
              } else if (document.caretRangeFromPoint) {
                const range = document.caretRangeFromPoint(x, y);
                if (range && range.startContainer && range.startContainer.nodeType === Node.TEXT_NODE) {
                  const node = range.startContainer;
                  const text = node.nodeValue || '';
                  const offset = range.startOffset;
                  let s = offset;
                  while (s > 0 && /\\w/.test(text[s - 1])) s--;
                  let e = offset;
                  while (e < text.length && /\\w/.test(text[e])) e++;
                  const wordRange = document.createRange();
                  wordRange.setStart(node, s);
                  wordRange.setEnd(node, e);
                  const sel = window.getSelection();
                  if (sel) {
                    sel.removeAllRanges();
                    sel.addRange(wordRange);
                  }
                }
              }
            } catch (e) {}
          } else if (count === 3) {
            try {
              if (editable && editable.select) {
                editable.select();
              } else {
                document.execCommand('selectAll', false, null);
              }
            } catch (e) {}
          }
          return !!(editable && !editable.disabled && !editable.readOnly);
        })();
        """

        webView.evaluateJavaScript(script) { result, _ in
            let editable = result as? Bool ?? false
            Task { @MainActor in completion(editable) }
        }
    }

    func contextClick(key: String, x: CGFloat, y: CGFloat) {
        lastPrimaryClick.removeValue(forKey: key)
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
        lastPrimaryClick.removeValue(forKey: key)
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

          // Dispatch key events first — some sites use keydown listeners
          const options = {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable:true};
          el.dispatchEvent(new KeyboardEvent('keydown', options));
          el.dispatchEvent(new KeyboardEvent('keypress', options));
          el.dispatchEvent(new KeyboardEvent('keyup', options));

          // Strategy 1: Find and click the form's submit button directly.
          // This is the most reliable approach for Google, YouTube, and
          // standard web forms since synthetic KeyboardEvents are untrusted
          // in WebKit and many sites ignore them.
          const form = el.form || el.closest?.('form');
          if (form) {
            const submitBtn = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
            if (submitBtn) {
              submitBtn.click();
              return true;
            }
            // Fallback: use requestSubmit for HTML5 validation, or submit()
            try {
              if (form.requestSubmit) form.requestSubmit();
              else form.submit();
            } catch (e) {}
            return true;
          }

          // Strategy 2: Find a nearby search/submit button by common patterns
          // used by YouTube, Google, and SPAs that don't use <form> elements.
          const container = el.closest?.('[role="search"], [role="combobox"], .search-box, .search-container, #search-form') || el.parentElement;
          if (container) {
            const nearbyBtn = container.querySelector('button[aria-label*="earch"], button[type="submit"], [role="button"][aria-label*="earch"], button.search-icon, button svg');
            if (nearbyBtn) {
              const btn = nearbyBtn.closest?.('button, [role="button"]') || nearbyBtn;
              btn.click();
              return true;
            }
          }

          // Strategy 3: For YouTube specifically, the search icon button
          const ytSearch = document.querySelector('#search-icon-legacy, button#search-icon-legacy, ytd-searchbox button');
          if (ytSearch) {
            ytSearch.click();
            return true;
          }

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
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Keep WebKit's real iOS user agent so sites can correctly detect the
        // platform capabilities used by Password AutoFill, passkeys, OAuth,
        // CAPTCHA and file pickers. Desktop layout is requested separately via
        // preferredContentMode; Kamihi must not impersonate macOS Safari.
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.allowsBackForwardNavigationGestures = false
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

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
        webView.navigationDelegate = context.coordinator
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
        webView.navigationDelegate = nil
        DesktopWebInputRegistry.shared.unregister(webView)
        webView.removeFromSuperview()
    }

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
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

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // iOS can reclaim a standalone ChatGPT/YouTube/Takeover renderer during
            // a long external-display session. Recover only while this WebView is
            // still presented; dismantled/hidden apps must not restart network or
            // media work. Authentication cookies/session state remain owned by
            // WebKit's default data store and are never read by Kamihi.
            guard webView.superview != nil else { return }
            webView.reload()
        }
    }
}
