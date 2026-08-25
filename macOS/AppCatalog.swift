import AppKit

enum AppCatalog {
    static func launchableApplications() -> [HostAppEntry] {
        let directories = [
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        var seen = Set<String>()
        var apps: [HostAppEntry] = []
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, seen.contains(id) == false else { continue }
                seen.insert(id)
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(HostAppEntry(displayName: name, bundleIdentifier: id))
                if apps.count > 400 { return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending } }
            }
        }
        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    @discardableResult
    static func open(bundleIdentifier: String) -> Bool {
        let workspace = NSWorkspace.shared
        if let running = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return running.activate()
        }
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return workspace.launchApplication(bundleIdentifier)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration)
        return true
    }
}
