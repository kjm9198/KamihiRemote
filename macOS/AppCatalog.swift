import AppKit

private struct LaunchableApp {
    var entry: HostAppEntry
    var url: URL
}

enum AppCatalog {
    private static let roots = [
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    static func launchableApplications() -> [HostAppEntry] {
        discoveredApplications()
            .map(\.entry)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    @discardableResult
    static func open(bundleIdentifier: String) -> Bool {
        let workspace = NSWorkspace.shared
        let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? discoveredApplications().first(where: { $0.entry.bundleIdentifier == bundleIdentifier })?.url

        guard let url else {
            NSLog("Kamihi Deck: app not found for bundle id %@", bundleIdentifier)
            return false
        }

        // Use the current AppKit launch API for both already-running and closed apps.
        // `activates = true` matches the user's explicit Deck intent to bring that app
        // forward without relying on deprecated force-activation flags.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("Kamihi Deck: failed to open %@: %@", bundleIdentifier, error.localizedDescription)
            }
        }
        return true
    }

    private static func discoveredApplications() -> [LaunchableApp] {
        var seen = Set<String>()
        var apps: [LaunchableApp] = []

        for directory in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app",
                      let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      seen.contains(id) == false
                else { continue }

                seen.insert(id)
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                apps.append(
                    LaunchableApp(
                        entry: HostAppEntry(displayName: name, bundleIdentifier: id),
                        url: url
                    )
                )

                if apps.count >= 400 {
                    return apps
                }
            }
        }

        return apps
    }
}
