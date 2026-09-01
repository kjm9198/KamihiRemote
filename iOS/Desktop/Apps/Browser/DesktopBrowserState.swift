import SwiftUI
import WebKit

/// State model for desktop browser tabs, session restoration, bookmarks and history.
@MainActor
public final class DesktopBrowserState: ObservableObject {
    public static let shared = DesktopBrowserState()

    public struct Tab: Identifiable, Equatable, Codable {
        public var id: UUID
        public var title: String
        public var url: URL?
        public var isLoading: Bool

        public init(
            id: UUID = UUID(),
            title: String = "New Tab",
            url: URL? = URL(string: "https://www.google.com"),
            isLoading: Bool = false
        ) {
            self.id = id
            self.title = title
            self.url = url
            self.isLoading = isLoading
        }
    }

    public struct Bookmark: Identifiable, Equatable, Codable {
        public var id: UUID
        public var title: String
        public var url: URL

        public init(id: UUID = UUID(), title: String, url: URL) {
            self.id = id
            self.title = title
            self.url = url
        }
    }

    public struct HistoryItem: Identifiable, Equatable, Codable {
        public var id: UUID
        public var title: String
        public var url: URL
        public var visitedAt: Date

        public init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = Date()) {
            self.id = id
            self.title = title
            self.url = url
            self.visitedAt = visitedAt
        }
    }

    @Published public private(set) var tabs: [Tab]
    @Published public var activeTabID: UUID
    @Published public var urlInput: String
    @Published public private(set) var currentURLText: String
    @Published public private(set) var title: String
    @Published public private(set) var canGoBack: Bool = false
    @Published public private(set) var canGoForward: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var bookmarks: [Bookmark]
    @Published public private(set) var history: [HistoryItem]

    private let defaults = UserDefaults.standard
    private let tabsKey = "kamihi.desktop.browser.tabs.v1"
    private let activeTabKey = "kamihi.desktop.browser.activeTab.v1"
    private let bookmarksKey = "kamihi.desktop.browser.bookmarks.v1"
    private let historyKey = "kamihi.desktop.browser.history.v1"
    private let encoder = JSONEncoder()

    private init() {
        let defaults = UserDefaults.standard
        let restoredTabs: [Tab] = Self.decode([Tab].self, from: defaults.data(forKey: "kamihi.desktop.browser.tabs.v1")) ?? []
        let initialTabs = restoredTabs.isEmpty ? [Tab()] : restoredTabs.map {
            var tab = $0
            tab.isLoading = false
            return tab
        }

        let resolvedActiveTabID: UUID
        if let storedID = defaults.string(forKey: "kamihi.desktop.browser.activeTab.v1").flatMap(UUID.init(uuidString:)),
           initialTabs.contains(where: { $0.id == storedID }) {
            resolvedActiveTabID = storedID
        } else {
            resolvedActiveTabID = initialTabs[0].id
        }

        let active = initialTabs.first(where: { $0.id == resolvedActiveTabID }) ?? initialTabs[0]
        let restoredBookmarks = Self.decode([Bookmark].self, from: defaults.data(forKey: "kamihi.desktop.browser.bookmarks.v1")) ?? []
        let restoredHistory = Self.decode([HistoryItem].self, from: defaults.data(forKey: "kamihi.desktop.browser.history.v1")) ?? []

        tabs = initialTabs
        activeTabID = resolvedActiveTabID
        urlInput = active.url?.absoluteString ?? ""
        currentURLText = active.url?.absoluteString ?? ""
        title = active.title
        bookmarks = restoredBookmarks
        history = restoredHistory
    }

    public var activeTab: Tab? {
        tabs.first(where: { $0.id == activeTabID })
    }

    public var isActivePageBookmarked: Bool {
        guard let url = activeTab?.url else { return false }
        return bookmarks.contains(where: { $0.url == url })
    }

    public func newTab(url: URL? = URL(string: "https://www.google.com")) {
        let tab = Tab(title: titleForURL(url), url: url)
        tabs.append(tab)
        selectTab(id: tab.id)
        persistTabs()
    }

    public func closeTab(id: UUID) {
        let closingIndex = tabs.firstIndex(where: { $0.id == id })
        tabs.removeAll(where: { $0.id == id })
        if tabs.isEmpty {
            let replacement = Tab()
            tabs = [replacement]
            activeTabID = replacement.id
        } else if activeTabID == id {
            let candidateIndex = min(closingIndex ?? 0, tabs.count - 1)
            activeTabID = tabs[candidateIndex].id
        }
        syncActiveMetadata()
        persistTabs()
    }

    public func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        syncActiveMetadata()
        persistTabs()
    }

    public func navigateActiveTab(to url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].url = url
        tabs[index].title = titleForURL(url)
        urlInput = url.absoluteString
        currentURLText = url.absoluteString
        persistTabs()
    }

    public func updateNavigationState(
        tabID: UUID,
        url: URL?,
        pageTitle: String?,
        isLoading: Bool,
        canGoBack: Bool,
        canGoForward: Bool,
        recordVisit: Bool = false
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if let url { tabs[index].url = url }
        if let pageTitle, !pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tabs[index].title = pageTitle
        }
        tabs[index].isLoading = isLoading

        if activeTabID == tabID {
            self.isLoading = isLoading
            self.canGoBack = canGoBack
            self.canGoForward = canGoForward
            currentURLText = tabs[index].url?.absoluteString ?? ""
            urlInput = currentURLText
            title = tabs[index].title
        }

        if recordVisit, let visitedURL = tabs[index].url {
            recordHistory(title: tabs[index].title, url: visitedURL)
        }
        persistTabs()
    }

    public func toggleBookmarkForActivePage() {
        guard let tab = activeTab, let url = tab.url else { return }
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.insert(Bookmark(title: tab.title, url: url), at: 0)
        }
        persistLibrary()
    }

    public func removeBookmark(id: UUID) {
        bookmarks.removeAll(where: { $0.id == id })
        persistLibrary()
    }

    public func clearHistory() {
        history.removeAll()
        persistLibrary()
    }

    public static func normalizeURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(" ") || (!trimmed.contains(".") && !trimmed.contains("://")) {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            return components?.url
        } else if trimmed.contains("://") {
            return URL(string: trimmed)
        } else {
            return URL(string: "https://\(trimmed)")
        }
    }

    private func syncActiveMetadata() {
        guard let tab = activeTab else { return }
        urlInput = tab.url?.absoluteString ?? ""
        currentURLText = urlInput
        title = tab.title
        isLoading = tab.isLoading
        canGoBack = false
        canGoForward = false
    }

    private func recordHistory(title: String, url: URL) {
        history.removeAll(where: { $0.url == url })
        history.insert(HistoryItem(title: title, url: url), at: 0)
        if history.count > 100 {
            history.removeLast(history.count - 100)
        }
        persistLibrary()
    }

    private func persistTabs() {
        defaults.set(try? encoder.encode(tabs), forKey: tabsKey)
        defaults.set(activeTabID.uuidString, forKey: activeTabKey)
    }

    private func persistLibrary() {
        defaults.set(try? encoder.encode(bookmarks), forKey: bookmarksKey)
        defaults.set(try? encoder.encode(history), forKey: historyKey)
    }

    private func titleForURL(_ url: URL?) -> String {
        guard let url else { return "New Tab" }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? "Web"
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
