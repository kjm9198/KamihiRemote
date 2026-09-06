import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Compatibility import path for user-selected Safari bookmark exports.
///
/// Safari exports are not completely uniform across macOS/iOS versions and
/// third-party transfer tools: some are Netscape bookmark HTML while others are
/// property lists whose bookmark dictionaries are nested under different keys.
/// Keep the existing privacy/sanitisation path in `DesktopBrowserState` as the
/// final writer, but normalize those variants before handing them to it.
@MainActor
extension DesktopBrowserState {
    @discardableResult
    public func importSafariBookmarks(from url: URL) throws -> Int {
        // A document picker URL can either require a security scope or already be
        // copied into Kamihi's sandbox. `startAccessing...` legitimately returns
        // false in the latter case, so never treat false as an import failure.
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try importSafariBookmarks(data)
    }

    @discardableResult
    public func importSafariBookmarks(_ data: Data) throws -> Int {
        do {
            return try importBookmarksHTML(data)
        } catch let originalError {
            let candidates = Self.safariBookmarkCandidates(in: data)
            guard !candidates.isEmpty else { throw originalError }

            let existingURLs = Set(bookmarks.map(\.url))
            var seen = existingURLs
            var normalized: [(String, URL)] = []

            for candidate in candidates {
                guard let rawURL = URL(string: candidate.url),
                      let safeURL = Self.historySafeURL(rawURL) else { continue }
                guard seen.insert(safeURL).inserted else { continue }
                let title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = safeURL.host?.replacingOccurrences(of: "www.", with: "") ?? "Bookmark"
                normalized.append((title.isEmpty ? fallback : title, safeURL))
            }

            // The file was valid and contained supported bookmarks, but all of
            // them are already present. That is a successful no-op, not an error.
            if normalized.isEmpty {
                let containsSupportedURL = candidates.contains { item in
                    guard let url = URL(string: item.url) else { return false }
                    return Self.historySafeURL(url) != nil
                }
                if containsSupportedURL { return 0 }
                throw originalError
            }

            let html = Self.normalizedBookmarkHTML(normalized)
            guard let normalizedData = html.data(using: .utf8) else { throw originalError }
            return try importBookmarksHTML(normalizedData)
        }
    }

    private struct SafariBookmarkCandidate {
        let title: String
        let url: String
    }

    private static func safariBookmarkCandidates(in data: Data) -> [SafariBookmarkCandidate] {
        var results: [SafariBookmarkCandidate] = []
        var seenRawURLs = Set<String>()

        if let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            collectSafariPlistBookmarks(root, into: &results, seenRawURLs: &seenRawURLs)
        }

        // Also accept looser HTML exports (including unquoted href attributes)
        // that the strict Netscape parser intentionally rejects.
        if let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252) {
            collectLooseHTMLBookmarks(html, into: &results, seenRawURLs: &seenRawURLs)
        }
        return results
    }

    private static func collectSafariPlistBookmarks(
        _ value: Any,
        into results: inout [SafariBookmarkCandidate],
        seenRawURLs: inout Set<String>
    ) {
        if let dictionary = value as? [String: Any] {
            let type = dictionary["WebBookmarkType"] as? String
            let isFolder = type == "WebBookmarkTypeList"
            let rawURL = ["URLString", "WebBookmarkURL", "URL", "url"]
                .compactMap { dictionary[$0] as? String }
                .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            if !isFolder, let rawURL {
                let cleanURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if seenRawURLs.insert(cleanURL).inserted {
                    let uriTitle = (dictionary["URIDictionary"] as? [String: Any])?["title"] as? String
                    let title = uriTitle
                        ?? dictionary["Title"] as? String
                        ?? dictionary["title"] as? String
                        ?? dictionary["Name"] as? String
                        ?? ""
                    results.append(.init(title: title, url: cleanURL))
                }
            }

            // Recurse through every nested container rather than assuming Safari
            // always stores folders under one exact `Children` key.
            for nested in dictionary.values {
                if nested is [String: Any] || nested is [Any] {
                    collectSafariPlistBookmarks(nested, into: &results, seenRawURLs: &seenRawURLs)
                }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectSafariPlistBookmarks(nested, into: &results, seenRawURLs: &seenRawURLs)
            }
        }
    }

    private static func collectLooseHTMLBookmarks(
        _ html: String,
        into results: inout [SafariBookmarkCandidate],
        seenRawURLs: inout Set<String>
    ) {
        let pattern = #"(?is)<a\b[^>]*\bhref\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)

        for match in regex.matches(in: html, range: fullRange) {
            guard match.numberOfRanges >= 5 else { continue }
            let href = (1...3).compactMap { index -> String? in
                guard match.range(at: index).location != NSNotFound,
                      let range = Range(match.range(at: index), in: html) else { return nil }
                return String(html[range])
            }.first ?? ""
            guard !href.isEmpty else { continue }

            let decodedURL = decodeSafariHTMLEntities(href).trimmingCharacters(in: .whitespacesAndNewlines)
            guard seenRawURLs.insert(decodedURL).inserted else { continue }

            var title = ""
            if let titleRange = Range(match.range(at: 4), in: html) {
                title = String(html[titleRange])
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                title = decodeSafariHTMLEntities(title)
            }
            results.append(.init(title: title, url: decodedURL))
        }
    }

    private static func decodeSafariHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static func normalizedBookmarkHTML(_ bookmarks: [(String, URL)]) -> String {
        let rows = bookmarks.map { title, url in
            "<DT><A HREF=\"\(escapeHTMLAttribute(url.absoluteString))\">\(escapeHTMLText(title))</A>"
        }.joined(separator: "\n")
        return """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">
        <TITLE>Kamihi Safari Import</TITLE>
        <H1>Bookmarks</H1>
        <DL><p>
        \(rows)
        </DL><p>
        """
    }

    private static func escapeHTMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeHTMLText(_ value: String) -> String {
        escapeHTMLAttribute(value).replacingOccurrences(of: "'", with: "&#39;")
    }
}

/// Presents the Safari picker on the iPhone application scene even when the
/// command originated from the non-interactive external desktop Settings window.
@MainActor
final class DesktopSafariImportPresenter: NSObject, ObservableObject, UIDocumentPickerDelegate {
    static let shared = DesktopSafariImportPresenter()

    @Published private(set) var lastMessage = "No Safari import run yet."
    @Published private(set) var revision = 0

    private override init() { super.init() }

    func present() {
        guard let presenter = Self.phonePresenter() else {
            updateMessage("Open Kamihi Desktop on the iPhone, then try Import again.")
            return
        }
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.html, .propertyList, .data],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            updateMessage("No bookmark file was selected.")
            return
        }
        do {
            let count = try DesktopBrowserState.shared.importSafariBookmarks(from: url)
            updateMessage(count == 0 ? "Safari bookmarks are already up to date." : "Imported \(count) Safari bookmark\(count == 1 ? "" : "s").")
            if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        } catch {
            updateMessage("Safari import failed: \(error.localizedDescription)")
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        updateMessage("Safari import cancelled.")
    }

    private func updateMessage(_ message: String) {
        lastMessage = message
        revision &+= 1
    }

    private static func phonePresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
        guard let scene = scenes.first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController else { return nil }
        return topController(from: root)
    }

    private static func topController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topController(from: presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topController(from: visible)
        }
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
            return topController(from: selected)
        }
        return controller
    }
}
