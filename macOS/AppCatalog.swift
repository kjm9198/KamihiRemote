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
                apps.append(HostAppEntry(displayName: name, bundleIdentifier: id, catalogPath: url.path))
                if apps.count > 400 {
                    return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                }
            }
        }
        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func open(bundleIdentifier: String, catalogPath: String? = nil) async -> (Bool, String) {
        let workspace = NSWorkspace.shared
        if let running = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            let activated = running.activate()
            return (activated, activated ? "Opened" : "Could not bring \(bundleIdentifier) forward")
        }
        let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? catalogPath.map { URL(fileURLWithPath: $0) }
        guard let url else {
            return (false, "App not found")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            workspace.openApplication(at: url, configuration: configuration) { app, error in
                if let error {
                    continuation.resume(returning: (false, error.localizedDescription))
                } else if app != nil {
                    continuation.resume(returning: (true, "Opened"))
                } else {
                    continuation.resume(returning: (false, "Launch did not complete"))
                }
            }
        }
    }
}
