import SwiftUI
import WebKit

/// State model for desktop browser tabs and navigation.
@MainActor
public final class DesktopBrowserState: ObservableObject {
    public static let shared = DesktopBrowserState()

    public struct Tab: Identifiable, Equatable {
        public let id = UUID()
        public var title: String
        public var url: URL?
        public var isLoading: Bool

        public init(title: String = "New Tab", url: URL? = URL(string: "https://www.google.com"), isLoading: Bool = false) {
            self.title = title
            self.url = url
            self.isLoading = isLoading
        }
    }

    @Published public var tabs: [Tab]
    @Published public var activeTabID: UUID
    @Published public var urlInput: String = "https://www.google.com"
    @Published public var currentURLText: String = "https://www.google.com"
    @Published public var title: String = ""
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var isLoading: Bool = false

    private init() {
        let initial = Tab()
        self.tabs = [initial]
        self.activeTabID = initial.id
    }

    public var activeTab: Tab? {
        tabs.first(where: { $0.id == activeTabID })
    }

    public func newTab(url: URL? = URL(string: "https://www.google.com")) {
        let tab = Tab(url: url)
        tabs.append(tab)
        activeTabID = tab.id
        urlInput = url?.absoluteString ?? ""
    }

    public func closeTab(id: UUID) {
        tabs.removeAll(where: { $0.id == id })
        if tabs.isEmpty {
            newTab()
        } else if activeTabID == id {
            activeTabID = tabs.last!.id
        }
    }

    public static func normalizeURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(" ") || (!trimmed.contains(".") && !trimmed.contains("://")) {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        } else if trimmed.contains("://") {
            return URL(string: trimmed)
        } else {
            return URL(string: "https://\(trimmed)")
        }
    }
}
