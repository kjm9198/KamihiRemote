import SwiftUI
import UIKit
import WebKit

/// "Continue on iPhone" takeover sheet.
///
/// Authentication remains inside WebKit/iOS so Password AutoFill, passkeys,
/// CAPTCHAs and document/photo upload controls can use the phone's native
/// interaction surfaces. Kamihi never reads, copies, logs or persists raw
/// credentials from the page.
struct PhoneTakeoverView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    let windowID: UUID

    @State private var currentURL: URL?
    @State private var pageTitle = "Continue on iPhone"
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                securityBanner

                if let window = desktop.windows.first(where: { $0.id == windowID }) {
                    TakeoverWebView(
                        initialURL: initialURL(for: window.title),
                        currentURL: $currentURL,
                        pageTitle: $pageTitle,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        webView: $webView
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Window Closed",
                        systemImage: "rectangle.slash",
                        description: Text("Return to the desktop and choose another window.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                navigationBar
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Return") {
                        finishTakeover()
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel("Return to Kamihi Desktop")
                }
            }
        }
        .interactiveDismissDisabled(isLoading)
        .onDisappear {
            // A swipe-to-dismiss after loading is a valid way to leave this sheet.
            // Synchronize the final URL on every dismissal path so OAuth redirects
            // are not lost merely because the user did not tap the Return button.
            synchronizeBrowserURL()
        }
    }

    private var securityBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: transportSecuritySymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(transportSecurityTint)

            VStack(alignment: .leading, spacing: 1) {
                Text(transportSecurityTitle)
                    .font(.caption.weight(.semibold))
                Text(transportSecurityDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Page loading")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transportSecurityTitle). \(transportSecurityDetail)")
    }

    private var transportSecurityTitle: String {
        guard let scheme = currentURL?.scheme?.lowercased() else {
            return "Private phone interaction"
        }
        switch scheme {
        case "https":
            return "Encrypted web connection"
        case "http":
            return "Connection not encrypted"
        default:
            return "Private phone interaction"
        }
    }

    private var transportSecurityDetail: String {
        guard let scheme = currentURL?.scheme?.lowercased() else {
            return "AutoFill, passkeys, CAPTCHA and file pickers stay inside iPhone and WebKit."
        }
        switch scheme {
        case "https":
            return "HTTPS is active; AutoFill, passkeys and page credentials stay inside iPhone and WebKit."
        case "http":
            return "Do not enter passwords or sensitive information on this unencrypted HTTP page."
        default:
            return "This interaction stays on iPhone; Kamihi does not read or store page credentials."
        }
    }

    private var transportSecuritySymbol: String {
        switch currentURL?.scheme?.lowercased() {
        case "https":
            return "lock.shield.fill"
        case "http":
            return "exclamationmark.triangle.fill"
        default:
            return "hand.raised.fill"
        }
    }

    private var transportSecurityTint: Color {
        switch currentURL?.scheme?.lowercased() {
        case "https":
            return Color(uiColor: .systemGreen)
        case "http":
            return Color(uiColor: .systemOrange)
        default:
            return .accentColor
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            Button {
                webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            Button {
                webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Forward")

            Button {
                if isLoading {
                    webView?.stopLoading()
                } else {
                    webView?.reload()
                }
            } label: {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isLoading ? "Stop loading" : "Reload")

            VStack(alignment: .leading, spacing: 1) {
                Text(currentURL?.host ?? "Web")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(safeDisplayOrigin)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    /// The takeover chrome intentionally never renders the complete navigation URL.
    /// OAuth callbacks can carry short-lived authorization codes, state values or
    /// tokens in their query/fragment. WebKit keeps using the full URL internally,
    /// while Kamihi only exposes the non-sensitive origin in its own UI.
    private var safeDisplayOrigin: String {
        guard let currentURL,
              let scheme = currentURL.scheme?.lowercased(),
              let host = currentURL.host else {
            return "WebKit session"
        }

        if let port = currentURL.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private func initialURL(for title: String) -> URL? {
        switch title {
        case "Browser":
            return DesktopBrowserState.shared.activeTab?.url ?? URL(string: "https://www.google.com")
        case "ChatGPT":
            return URL(string: "https://chatgpt.com")
        case "YouTube":
            return URL(string: "https://www.youtube.com")
        default:
            return URL(string: "https://www.google.com")
        }
    }

    private func synchronizeBrowserURL() {
        guard let window = desktop.windows.first(where: { $0.id == windowID }),
              window.title == "Browser",
              let currentURL else { return }

        // Website cookies/session data already live in WKWebsiteDataStore.default().
        // Only the final navigation URL is synchronized; Kamihi never extracts form
        // values, passwords, passkeys, tokens or other page credentials.
        DesktopBrowserState.shared.navigateActiveTab(to: currentURL)
    }

    private func finishTakeover() {
        synchronizeBrowserURL()
        dismiss()
    }
}

/// Dedicated interactive WebKit bridge for phone takeover.
/// It intentionally uses the default persistent website data store so login
/// cookies/session state are shared with Kamihi's other WebKit surfaces.
private struct TakeoverWebView: UIViewRepresentable {
    let initialURL: URL?
    @Binding var currentURL: URL?
    @Binding var pageTitle: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webView: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.allowsLinkPreview = true
        view.isOpaque = true
        view.backgroundColor = .systemBackground
        view.scrollView.backgroundColor = .systemBackground

        DispatchQueue.main.async {
            webView = view
        }

        if let initialURL {
            view.load(URLRequest(url: initialURL))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Navigation is intentionally owned by the live WebView after creation.
        // Re-applying initialURL here would undo OAuth redirects and form flows.
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: TakeoverWebView

        init(parent: TakeoverWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow)
                return
            }

            // Keep ordinary web and WebKit-owned navigations inside the secure
            // takeover. OAuth/SSO providers can legitimately hand off to another
            // installed app using a custom URL scheme; letting WebKit try to load
            // that scheme produces a dead-end error. Hand it to iOS instead using
            // the public UIApplication API without inspecting page/form contents.
            let webKitSchemes: Set<String> = ["http", "https", "about", "blob", "data", "file"]
            guard !webKitSchemes.contains(scheme) else {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            Task { @MainActor in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            publish(webView, loading: true)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            publish(webView, loading: true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            publish(webView, loading: false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            publish(webView, loading: false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            publish(webView, loading: false)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // OAuth providers and identity pages frequently use target=_blank or
            // window.open(). Keep those flows inside the takeover instead of
            // creating an invisible second window. Loading the original request
            // preserves its HTTP method, body and headers without Kamihi reading,
            // copying, logging or persisting any credential-bearing fields.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func publish(_ webView: WKWebView, loading: Bool) {
            Task { @MainActor in
                parent.currentURL = webView.url
                parent.pageTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (webView.title ?? "Continue on iPhone")
                    : "Continue on iPhone"
                parent.isLoading = loading
                parent.canGoBack = webView.canGoBack
                parent.canGoForward = webView.canGoForward
            }
        }
    }
}
