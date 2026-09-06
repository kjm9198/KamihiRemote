import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

/// Persistent desktop browser with one retained WKWebView per warm tab. The tab
/// strip and navigation controls use the same uniform Golden Gate toolbar system
/// as native Kamihi apps while preserving desktop Safari-style web behavior.
struct DesktopBrowserView: View {
    @StateObject private var state = DesktopBrowserState.shared
    @StateObject private var controller = DesktopBrowserController()
    @State private var showLibrary = false
    @State private var findText = ""
    @State private var showFind = false

    var onContinueOnPhone: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .frame(height: 36)
                .desktopAppToolbar()

            navigationBar
                .frame(height: 42)
                .desktopAppToolbar()

            if showFind {
                findBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            DesktopBrowserWebViewHost(
                state: state,
                controller: controller,
                tabID: state.activeTabID,
                url: state.activeTab?.url
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesktopShellPalette.canvas)
        .sheet(isPresented: $showLibrary) {
            BrowserLibrarySheet(state: state) { url in
                state.navigateActiveTab(to: url)
                controller.navigate(to: url)
                showLibrary = false
            }
        }
        .animation(KamihiTheme.Animation.fast, value: showFind)
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "safari.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 25, height: 25)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(.leading, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(state.tabs) { tab in
                        HStack(spacing: 0) {
                            Button {
                                state.selectTab(id: tab.id)
                            } label: {
                                HStack(spacing: 6) {
                                    if tab.isLoading {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: tab.id == state.activeTabID ? "globe" : "circle.fill")
                                            .font(.system(size: tab.id == state.activeTabID ? 10 : 4.5, weight: .semibold))
                                            .foregroundStyle(tab.id == state.activeTabID ? Color.accentColor : Color.secondary.opacity(0.55))
                                    }

                                    Text(tab.title)
                                        .font(.system(size: 11.5, weight: tab.id == state.activeTabID ? .semibold : .medium))
                                        .foregroundStyle(.primary.opacity(0.90))
                                        .lineLimit(1)
                                        .frame(maxWidth: 146, alignment: .leading)
                                }
                                .padding(.leading, 9)
                                .padding(.trailing, 3)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Tab \(tab.title)")

                            Button {
                                controller.closeTab(tab.id)
                                state.closeTab(id: tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close \(tab.title) tab")
                        }
                        .padding(.trailing, 2)
                        .background(
                            tab.id == state.activeTabID ? Color.primary.opacity(0.075) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            if tab.id == state.activeTabID {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                            }
                        }
                    }
                }
                .padding(.horizontal, 3)
            }

            Button { state.newTab() } label: {
                DesktopToolbarIconLabel("plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New tab")
            .padding(.trailing, 7)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 5) {
            browserButton("chevron.left", label: "Back", enabled: state.canGoBack) { controller.goBack() }
            browserButton("chevron.right", label: "Forward", enabled: state.canGoForward) { controller.goForward() }
            browserButton(state.isLoading ? "xmark" : "arrow.clockwise", label: state.isLoading ? "Stop" : "Reload") {
                state.isLoading ? controller.stopLoading() : controller.reload()
            }

            HStack(spacing: 7) {
                Image(systemName: state.currentURLText.hasPrefix("https://") ? "lock.fill" : "globe")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search or enter website name", text: $state.urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .submitLabel(.go)
                    .onSubmit(navigateFromAddressBar)

                if !state.urlInput.isEmpty {
                    Button { state.urlInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear address")
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: 620)
            .frame(height: 30)
            .background(Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }

            browserButton(state.isActivePageBookmarked ? "star.fill" : "star", label: state.isActivePageBookmarked ? "Remove Bookmark" : "Bookmark") {
                state.toggleBookmarkForActivePage()
            }
            browserButton("text.magnifyingglass", label: "Find on Page") {
                showFind.toggle()
                if !showFind {
                    findText = ""
                    controller.find("")
                }
            }
            browserButton("book.pages", label: "Bookmarks and History") { showLibrary = true }

            if let url = state.activeTab?.url {
                ShareLink(item: url) {
                    DesktopToolbarIconLabel("square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share Page")
            }

            if let onContinueOnPhone {
                Button(action: onContinueOnPhone) {
                    DesktopToolbarIconLabel("iphone.and.arrow.forward")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue on iPhone")
            }
        }
        .padding(.horizontal, 8)
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Find on this page", text: $findText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit { controller.find(findText) }
                .onChange(of: findText) { _, value in controller.find(value) }
            Button("Done") {
                showFind = false
                findText = ""
                controller.find("")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .desktopAppToolbar()
    }

    private func browserButton(
        _ symbol: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(enabled ? Color.primary.opacity(0.86) : Color.secondary.opacity(0.35))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(enabled ? 0.04 : 0.02), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func navigateFromAddressBar() {
        guard let url = DesktopBrowserState.normalizeURL(state.urlInput) else { return }
        state.navigateActiveTab(to: url)
        controller.navigate(to: url)
    }
}

@MainActor
final class DesktopBrowserController: ObservableObject {
    private var webViews: [UUID: WKWebView] = [:]
    private var delegates: [UUID: DesktopBrowserNavigationDelegate] = [:]
    private var activationOrder: [UUID] = []
    private var activeTabID: UUID?
    private var lifecycleObservers: [NSObjectProtocol] = []

    private var maximumRetainedWebViews: Int {
        let processInfo = ProcessInfo.processInfo
        let thermal = processInfo.thermalState
        if processInfo.isLowPowerModeEnabled || thermal == .serious || thermal == .critical {
            return 2
        }
        return 6
    }

    init() {
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.releaseInactiveWebViews() }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.releaseInactiveWebViews() }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.trimForCurrentSystemPressure() }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.trimForCurrentSystemPressure() }
            }
        )
    }

    deinit {
        for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
    }

    func present(tabID: UUID, url: URL?, in container: UIView, state: DesktopBrowserState) {
        let webView = webView(for: tabID, state: state)
        activeTabID = tabID
        markTabActive(tabID)
        trimRetainedWebViews(excluding: tabID)
        DesktopWebInputRegistry.shared.register(webView, key: "Browser")

        if webView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            webView.frame = container.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(webView)
        }

        if let url, webView.url != url {
            webView.load(URLRequest(url: url))
        } else {
            state.updateNavigationState(
                tabID: tabID,
                url: webView.url ?? url,
                pageTitle: webView.title,
                isLoading: webView.isLoading,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
        }
    }

    func closeTab(_ id: UUID) {
        releaseWebView(for: id)
        activationOrder.removeAll(where: { $0 == id })
        if activeTabID == id { activeTabID = nil }
    }

    func navigate(to url: URL) { currentWebView?.load(URLRequest(url: url)) }
    func goBack() { guard currentWebView?.canGoBack == true else { return }; currentWebView?.goBack() }
    func goForward() { guard currentWebView?.canGoForward == true else { return }; currentWebView?.goForward() }
    func reload() { currentWebView?.reload() }
    func stopLoading() { currentWebView?.stopLoading() }

    func find(_ text: String) {
        guard let webView = currentWebView else { return }
        if text.isEmpty {
            webView.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = false
        configuration.wraps = true
        webView.find(text, configuration: configuration) { _ in }
    }

    private var currentWebView: WKWebView? {
        guard let activeTabID else { return nil }
        return webViews[activeTabID]
    }

    private func webView(for id: UUID, state: DesktopBrowserState) -> WKWebView {
        if let existing = webViews[id] { return existing }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.allowsBackForwardNavigationGestures = false

        let delegate = DesktopBrowserNavigationDelegate(tabID: id, state: state)
        webView.navigationDelegate = delegate
        delegates[id] = delegate
        webViews[id] = webView
        return webView
    }

    private func markTabActive(_ id: UUID) {
        activationOrder.removeAll(where: { $0 == id })
        activationOrder.append(id)
    }

    private func trimRetainedWebViews(excluding activeID: UUID) {
        while webViews.count > maximumRetainedWebViews {
            guard let evictionID = activationOrder.first(where: { $0 != activeID && webViews[$0] != nil }) else { return }
            activationOrder.removeAll(where: { $0 == evictionID })
            releaseWebView(for: evictionID)
        }
    }

    private func trimForCurrentSystemPressure() {
        let processInfo = ProcessInfo.processInfo
        let thermal = processInfo.thermalState
        guard processInfo.isLowPowerModeEnabled || thermal == .serious || thermal == .critical else { return }
        guard let activeTabID else {
            releaseInactiveWebViews()
            return
        }
        trimRetainedWebViews(excluding: activeTabID)
    }

    private func releaseInactiveWebViews() {
        let inactiveIDs = webViews.keys.filter { $0 != activeTabID }
        for id in inactiveIDs {
            activationOrder.removeAll(where: { $0 == id })
            releaseWebView(for: id)
        }
    }

    private func releaseWebView(for id: UUID) {
        webViews[id]?.stopLoading()
        webViews[id]?.navigationDelegate = nil
        webViews[id]?.removeFromSuperview()
        webViews[id] = nil
        delegates[id] = nil
    }
}

struct DesktopBrowserWebViewHost: UIViewRepresentable {
    let state: DesktopBrowserState
    let controller: DesktopBrowserController
    let tabID: UUID
    let url: URL?

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        controller.present(tabID: tabID, url: url, in: container, state: state)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        controller.present(tabID: tabID, url: url, in: uiView, state: state)
    }
}

final class DesktopBrowserNavigationDelegate: NSObject, WKNavigationDelegate {
    private let tabID: UUID
    private weak var state: DesktopBrowserState?

    init(tabID: UUID, state: DesktopBrowserState) {
        self.tabID = tabID
        self.state = state
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { sync(webView, recordVisit: false) }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { sync(webView, recordVisit: false) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { sync(webView, recordVisit: true) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { sync(webView, recordVisit: false) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { sync(webView, recordVisit: false) }

    private func sync(_ webView: WKWebView, recordVisit: Bool) {
        let tabID = tabID
        let state = state
        let url = webView.url
        let title = webView.title
        let loading = webView.isLoading
        let canGoBack = webView.canGoBack
        let canGoForward = webView.canGoForward
        Task { @MainActor in
            state?.updateNavigationState(
                tabID: tabID,
                url: url,
                pageTitle: title,
                isLoading: loading,
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                recordVisit: recordVisit
            )
        }
    }
}

private struct BrowserLibrarySheet: View {
    @ObservedObject var state: DesktopBrowserState
    let openURL: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showBookmarkImporter = false
    @State private var bookmarkImportMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Bookmarks") {
                    Button {
                        bookmarkImportMessage = nil
                        showBookmarkImporter = true
                    } label: {
                        Label("Import Safari / Chrome Bookmarks", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityHint("Choose a bookmark HTML or Safari property-list export. Passwords and cookies are never imported.")

                    Text("Imports only bookmarks from a file you select. Kamihi never reads passwords, cookies, tokens, or another browser's private storage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let bookmarkImportMessage {
                        Text(bookmarkImportMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if state.bookmarks.isEmpty {
                        Text("No bookmarks yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(state.bookmarks) { bookmark in
                            Button { openURL(bookmark.url) } label: {
                                libraryRow(title: bookmark.title, url: bookmark.url)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for index in offsets { state.removeBookmark(id: state.bookmarks[index].id) }
                        }
                    }
                }

                Section {
                    if state.history.isEmpty {
                        Text("No browsing history yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(state.history) { item in
                            Button { openURL(item.url) } label: {
                                libraryRow(title: item.title, url: item.url)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("History")
                        Spacer()
                        if !state.history.isEmpty {
                            Button("Clear") { state.clearHistory() }
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Browser")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showBookmarkImporter,
            allowedContentTypes: [.html, .propertyList, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleBookmarkImport(result)
        }
    }

    private func handleBookmarkImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                bookmarkImportMessage = "No bookmark file was selected."
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let importedCount = try state.importBookmarksHTML(data)
            bookmarkImportMessage = "Imported \(importedCount) bookmark\(importedCount == 1 ? "" : "s")."
        } catch {
            bookmarkImportMessage = error.localizedDescription
        }
    }

    private func libraryRow(title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Text(url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}
