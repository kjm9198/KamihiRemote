import Foundation
import WebKit

/// Turns desktop-style `target=_blank` / `window.open` navigations into retained
/// Kamihi Browser tabs and lets normal WebKit downloads land in a Kamihi-owned
/// Downloads directory without exposing credentials or arbitrary filesystem access.
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
        // The file is already committed atomically by WebKit at the destination
        // chosen above. No credential, response-body, or browsing-data logging.
    }

    func download(
        _ download: WKDownload,
        didFailWithError error: Error,
        resumeData: Data?
    ) {
        // Intentionally do not persist resumeData: it can contain request/session
        // material. A later Browser downloads UI can surface a safe retry action.
    }

    private static func browserDownloadsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("Kamihi Desktop", isDirectory: true)
            .appendingPathComponent("Browser Downloads", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
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
