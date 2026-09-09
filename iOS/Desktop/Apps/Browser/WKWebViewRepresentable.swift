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
    private var fullscreenMaximizedByKamihi: Set<String> = []

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
            fullscreenMaximizedByKamihi.remove(key)
        }
    }

    private func pruneReleasedEntries() {
        let releasedKeys = webViews.compactMap { key, holder in holder.value == nil ? key : nil }
        webViews = webViews.filter { $0.value.value != nil }
        for key in releasedKeys {
            lastPrimaryClick.removeValue(forKey: key)
            fullscreenMaximizedByKamihi.remove(key)
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

        let youtubeMode = key == "YouTube" ? "true" : "false"
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const hit = document.elementFromPoint(x, y);
          if (!hit) return false;

          const youtubeMode = \(youtubeMode);
          const editable = hit.closest?.('input:not([type="button"]):not([type="submit"]):not([type="checkbox"]):not([type="radio"]), textarea, [contenteditable="true"], [role="textbox"]') || (hit.isContentEditable ? hit : null);
          if (editable && !editable.disabled && !editable.readOnly && editable.focus) {
            editable.focus();
          } else if (hit.focus) {
            hit.focus();
          }

          const anchor = hit.closest?.('a[href]');
          const interactive = hit.closest?.('a, button, [role="button"], [role="link"], input, select, textarea, video, audio') || hit;

          // WKWebView's native element-fullscreen support is enabled below, but an
          // external-display software pointer cannot manufacture WebKit's trusted
          // user-activation token. When the user targets YouTube's own fullscreen
          // control, use a reversible page-local presentation fallback and let the
          // desktop window maximize around it. Direct iPad/touch fullscreen can
          // still use WebKit's native fullscreen API.
          if (youtubeMode) {
            const fullscreenControl = hit.closest?.(
              '.ytp-fullscreen-button, button[aria-label*="full screen" i], button[aria-label*="fullscreen" i], button[title*="full screen" i], button[title*="fullscreen" i]'
            );
            if (fullscreenControl) {
              const root = document.querySelector('#movie_player') ||
                           hit.closest?.('#movie_player, ytd-player, ytd-reel-video-renderer') ||
                           document.querySelector('video')?.parentElement;
              if (root) {
                const styleID = 'kamihi-youtube-fullscreen-style';
                const active = document.documentElement.hasAttribute('data-kamihi-youtube-fullscreen');
                if (active) {
                  document.documentElement.removeAttribute('data-kamihi-youtube-fullscreen');
                  document.getElementById(styleID)?.remove();
                  root.removeAttribute?.('data-kamihi-fullscreen-target');
                  return 'kamihi-fullscreen-off';
                }

                const style = document.createElement('style');
                style.id = styleID;
                style.textContent = `
                  html[data-kamihi-youtube-fullscreen],
                  html[data-kamihi-youtube-fullscreen] body {
                    overflow: hidden !important;
                    background: #000 !important;
                  }
                  [data-kamihi-fullscreen-target] {
                    position: fixed !important;
                    inset: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    max-width: none !important;
                    max-height: none !important;
                    z-index: 2147483647 !important;
                    background: #000 !important;
                    margin: 0 !important;
                  }
                  [data-kamihi-fullscreen-target] video {
                    width: 100% !important;
                    height: 100% !important;
                    object-fit: contain !important;
                  }
                `;
                document.head.appendChild(style);
                document.documentElement.setAttribute('data-kamihi-youtube-fullscreen', 'true');
                root.setAttribute('data-kamihi-fullscreen-target', 'true');
                return 'kamihi-fullscreen-on';
              }
            }
          }

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

          if (anchor) {
            anchor.click();
          } else {
            hit.dispatchEvent(new PointerEvent('pointerdown', eventInit));
            hit.dispatchEvent(new MouseEvent('mousedown', eventInit));

            const upInit = Object.assign({}, eventInit, { buttons: 0 });
            hit.dispatchEvent(new PointerEvent('pointerup', upInit));
            hit.dispatchEvent(new MouseEvent('mouseup', upInit));
            hit.dispatchEvent(new MouseEvent('click', upInit));

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
                while (start > 0 && !/\s/.test(val[start - 1])) start--;
                let end = pos;
                while (end < val.length && !/\s/.test(val[end])) end++;
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
                  while (s > 0 && /\w/.test(text[s - 1])) s--;
                  let e = offset;
                  while (e < text.length && /\w/.test(text[e])) e++;
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
            Task { @MainActor in
                if let command = result as? String,
                   command == "kamihi-fullscreen-on" || command == "kamihi-fullscreen-off" {
                    if let window = DesktopSession.shared.windows.last(where: { $0.title == key }) {
                        if command == "kamihi-fullscreen-on" {
                            if !window.isMaximized {
                                DesktopSession.shared.toggleMaximize(window.id)
                                self.fullscreenMaximizedByKamihi.insert(key)
                            }
                        } else if self.fullscreenMaximizedByKamihi.remove(key) != nil,
                                  window.isMaximized {
                            DesktopSession.shared.toggleMaximize(window.id)
                        }
                    }
                    completion(false)
                    return
                }
                completion(result as? Bool ?? false)
            }
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
        guard let webView = webViews[key]?.value else {
            lastPrimaryClick.removeValue(forKey: key)
            return
        }

        // Keep the most recent click location as the preferred scroll target. This
        // lets Shorts, sidebars, comment panes, and other nested SPA scrollers own
        // the wheel/two-finger gesture instead of always moving WKWebView's root.
        let sample = lastPrimaryClick[key]
        let safeX = min(max(sample?.x ?? 0.5, 0), 1)
        let safeY = min(max(sample?.y ?? 0.5, 0), 1)
        let dx = Double(deltaX)
        let dy = Double(deltaY)
        let script = """
        (() => {
          const dx = \(dx);
          const dy = \(dy);
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const hit = document.elementFromPoint(x, y) || document.activeElement || document.body;
          if (!hit) return false;

          // Let app-level wheel listeners (including YouTube Shorts navigation)
          // observe the gesture before applying a direct overflow fallback.
          try {
            hit.dispatchEvent(new WheelEvent('wheel', {
              bubbles: true,
              cancelable: true,
              deltaX: dx,
              deltaY: dy,
              deltaMode: 0
            }));
          } catch (e) {}

          const canScroll = (node) => {
            if (!node || node === document.documentElement) return false;
            const style = getComputedStyle(node);
            const allowsY = /(auto|scroll|overlay)/.test(style.overflowY) && node.scrollHeight > node.clientHeight + 1;
            const allowsX = /(auto|scroll|overlay)/.test(style.overflowX) && node.scrollWidth > node.clientWidth + 1;
            return (Math.abs(dy) > 0.01 && allowsY) || (Math.abs(dx) > 0.01 && allowsX);
          };

          const move = (node) => {
            if (!canScroll(node)) return false;
            const beforeX = node.scrollLeft;
            const beforeY = node.scrollTop;
            node.scrollBy({left: dx, top: dy, behavior: 'auto'});
            return node.scrollLeft !== beforeX || node.scrollTop !== beforeY;
          };

          let node = hit;
          while (node && node !== document.body) {
            if (move(node)) return true;
            node = node.parentElement;
          }

          // SPA feeds frequently place the scroll owner beside rather than above
          // the element under the pointer. Prefer visible YouTube/feed containers,
          // then any large visible overflow container before falling back to root.
          const preferredSelectors = [
            'ytd-shorts',
            'ytd-reel-shelf-renderer',
            '#shorts-container',
            '#contents',
            '[role="feed"]',
            '[data-testid*="scroll"]'
          ];
          for (const selector of preferredSelectors) {
            for (const candidate of document.querySelectorAll(selector)) {
              const rect = candidate.getBoundingClientRect();
              if (rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < innerHeight && move(candidate)) {
                return true;
              }
            }
          }

          const candidates = Array.from(document.querySelectorAll('*'))
            .filter((candidate) => {
              if (!canScroll(candidate)) return false;
              const rect = candidate.getBoundingClientRect();
              return rect.width > 80 && rect.height > 80 && rect.bottom > 0 && rect.top < innerHeight && rect.right > 0 && rect.left < innerWidth;
            })
            .sort((a, b) => {
              const ar = a.getBoundingClientRect();
              const br = b.getBoundingClientRect();
              return (br.width * br.height) - (ar.width * ar.height);
            });
          for (const candidate of candidates) {
            if (move(candidate)) return true;
          }

          const beforeX = window.scrollX;
          const beforeY = window.scrollY;
          window.scrollBy({left: dx, top: dy, behavior: 'auto'});
          return window.scrollX !== beforeX || window.scrollY !== beforeY;
        })();
        """

        webView.evaluateJavaScript(script) { result, _ in
            guard (result as? Bool) != true else { return }
            Task { @MainActor in
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
        }
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
        let chatGPTSubmitMode = key == "ChatGPT" ? "true" : "false"
        let script = """
        (() => {
          const el = document.activeElement;
          if (!el) return false;
          const chatGPTSubmitMode = \(chatGPTSubmitMode);

          if (chatGPTSubmitMode && el.isContentEditable) {
            const keyOptions = {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable:true};

            const selectors = [
              '[data-testid="send-button"]',
              'button[aria-label="Send prompt"]',
              'button[aria-label="Send message"]',
              'button[type="submit"]'
            ];

            const composer = el.closest?.('form, [data-testid*="composer"], [class*="composer"]') || el.parentElement;
            let sendButton = null;

            // Prefer a document-level lookup first. ChatGPT's send control can be
            // rendered outside the focused contenteditable subtree by React/SPA
            // composition, and limiting the first search to a guessed ancestor made
            // Enter-to-send brittle in both the app and deterministic WebKit fixture.
            for (const selector of selectors) {
              const candidate = document.querySelector(selector);
              if (candidate && !candidate.disabled && candidate.getAttribute?.('aria-disabled') !== 'true') {
                sendButton = candidate;
                break;
              }
            }

            if (!sendButton && composer?.querySelector) {
              for (const selector of selectors) {
                const candidate = composer.querySelector(selector);
                if (candidate && !candidate.disabled && candidate.getAttribute?.('aria-disabled') !== 'true') {
                  sendButton = candidate;
                  break;
                }
              }
            }

            if (sendButton) {
              // Use the element's standards-based activation behavior exactly once.
              // This reaches normal DOM and delegated React click handlers without
              // double-applying pointer/mouse event sequences.
              try {
                sendButton.click();
              } catch (e) {
                return false;
              }
              return true;
            }

            // If the current ChatGPT markup exposes a form but no recognizable
            // send button, prefer native form submission over inserting a newline.
            const form = el.closest?.('form');
            if (form?.requestSubmit) {
              try {
                form.requestSubmit();
                return true;
              } catch (e) {}
            }

            // Last resort: let ChatGPT's own Enter key listener observe the key.
            // Do not synthesize a newline if its markup changes.
            try {
              el.dispatchEvent(new KeyboardEvent('keydown', keyOptions));
              el.dispatchEvent(new KeyboardEvent('keyup', keyOptions));
              return true;
            } catch (e) {
              return false;
            }
          }

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

          const options = {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable:true};
          el.dispatchEvent(new KeyboardEvent('keydown', options));
          el.dispatchEvent(new KeyboardEvent('keypress', options));
          el.dispatchEvent(new KeyboardEvent('keyup', options));

          const form = el.form || el.closest?.('form');
          if (form) {
            const submitBtn = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
            if (submitBtn) {
              submitBtn.click();
              return true;
            }
            try {
              if (form.requestSubmit) form.requestSubmit();
              else form.submit();
            } catch (e) {}
            return true;
          }

          const container = el.closest?.('[role="search"], [role="combobox"], .search-box, .search-container, #search-form') || el.parentElement;
          if (container) {
            const nearbyBtn = container.querySelector('button[aria-label*="earch"], button[type="submit"], [role="button"][aria-label*="earch"], button.search-icon, button svg');
            if (nearbyBtn) {
              const btn = nearbyBtn.closest?.('button, [role="button"]') || nearbyBtn;
              btn.click();
              return true;
            }
          }

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
        configuration.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
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
            guard navigationAction.targetFrame == nil,
                  let requestURL = navigationAction.request.url else { return nil }
            webView.load(URLRequest(url: requestURL))
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard webView.superview != nil else { return }
            webView.reload()
        }
    }
}