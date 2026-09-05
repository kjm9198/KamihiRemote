import Foundation
import UIKit
import WebKit

/// Turns desktop-style `target=_blank` / `window.open` navigations into retained
/// Kamihi Browser tabs and lets normal WebKit downloads land in Kamihi's native
/// Files library without exposing credentials or arbitrary filesystem access.
extension DesktopBrowserNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        guard let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        if scheme == "http" || scheme == "https" {
            guard navigationAction.targetFrame == nil else {
                decisionHandler(.allow)
                return
            }

            // Cancel the orphaned WebKit new-window request first, then let the
            // browser state create/select a normal retained tab on the main actor.
            decisionHandler(.cancel)
            Task { @MainActor in
                DesktopBrowserState.shared.newTab(url: url)
            }
            return
        }

        // Web apps commonly hand off mailto/tel links, Maps/App Store links, and
        // OAuth/deep-link callbacks to an iPhone app. A noninteractive external
        // WKWebView cannot present those system/app destinations itself, so route
        // public external schemes through UIApplication on the phone instead of
        // leaving the user on a dead/blank navigation. WebKit-owned schemes stay
        // inside WebKit; Kamihi never reads credentials or redirect payloads.
        let webKitOwnedSchemes: Set<String> = ["about", "blob", "data", "javascript"]
        guard !webKitOwnedSchemes.contains(scheme) else {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)
        Task { @MainActor in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        // If WebKit cannot render the response in-page, treat it as a download
        // instead of navigating the Browser to an unusable blank/error page.
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }
}

extension DesktopBrowserNavigationDelegate: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        do {
            let directory = try Self.browserDownloadsDirectory()
            let destination = Self.uniqueDownloadURL(
                in: directory,
                suggestedFilename: suggestedFilename
            )
            completionHandler(destination)
        } catch {
            // Failing closed is preferable to redirecting a download into an
            // arbitrary location. WebKit reports the failed download normally.
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        // WebKit committed the file directly into Kamihi Desktop Files, so the
        // native Files app can preview, share/export, or delete it on next open.
        // No credential, response-body, or browsing-data logging is involved.
    }

    func download(
        _ download: WKDownload,
        didFailWithError error: Error,
        resumeData: Data?
    ) {
        // Intentionally do not persist resumeData: it can contain request/session
        // material. A safe retry can start a fresh request instead.
    }

    private static func browserDownloadsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Browser downloads belong to the same Kamihi-owned library used by the
        // native Files app. This makes a completed download immediately useful:
        // Files can preview it with PDFKit/Quick Look, share/export it, or remove it.
        let directory = applicationSupport
            .appendingPathComponent("Kamihi Desktop Files", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Migrate downloads created by older builds from the browser-only silo.
        // Collision-safe moves preserve both files and avoid touching anything
        // outside Kamihi's Application Support container.
        let legacyDirectory = applicationSupport
            .appendingPathComponent("Kamihi Desktop", isDirectory: true)
            .appendingPathComponent("Browser Downloads", isDirectory: true)
        if fileManager.fileExists(atPath: legacyDirectory.path),
           let legacyFiles = try? fileManager.contentsOfDirectory(
                at: legacyDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
           ) {
            for legacyFile in legacyFiles {
                let destination = uniqueDownloadURL(
                    in: directory,
                    suggestedFilename: legacyFile.lastPathComponent
                )
                try? fileManager.moveItem(at: legacyFile, to: destination)
            }
            try? fileManager.removeItem(at: legacyDirectory)
        }

        return directory
    }

    private static func uniqueDownloadURL(
        in directory: URL,
        suggestedFilename: String
    ) -> URL {
        let fileManager = FileManager.default
        let safeName = sanitizedFilename(suggestedFilename)
        let baseURL = directory.appendingPathComponent(safeName, isDirectory: false)
        guard fileManager.fileExists(atPath: baseURL.path) else { return baseURL }

        let stem = baseURL.deletingPathExtension().lastPathComponent
        let pathExtension = baseURL.pathExtension
        for suffix in 2...999 {
            let candidateName = pathExtension.isEmpty
                ? "\(stem) \(suffix)"
                : "\(stem) \(suffix).\(pathExtension)"
            let candidate = directory.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let fallbackName = pathExtension.isEmpty
            ? "\(stem)-\(UUID().uuidString)"
            : "\(stem)-\(UUID().uuidString).\(pathExtension)"
        return directory.appendingPathComponent(fallbackName, isDirectory: false)
    }

    private static func sanitizedFilename(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "Download" : trimmed
        let forbidden = CharacterSet(charactersIn: "/\\:\0")
        let components = source.components(separatedBy: forbidden)
        let joined = components.filter { !$0.isEmpty }.joined(separator: "-")
        return joined.isEmpty ? "Download" : String(joined.prefix(180))
    }
}
