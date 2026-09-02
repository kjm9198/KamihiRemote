import WebKit

/// Turns desktop-style `target=_blank` / `window.open` navigations into retained
/// Kamihi Browser tabs. Without this policy WebKit asks for a separate web view;
/// the Browser intentionally owns one retained WKWebView per tab instead.
extension DesktopBrowserNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            decisionHandler(.allow)
            return
        }

        // Cancel the orphaned WebKit new-window request first, then let the
        // browser state create/select a normal retained tab on the main actor.
        decisionHandler(.cancel)
        Task { @MainActor in
            DesktopBrowserState.shared.newTab(url: url)
        }
    }
}
