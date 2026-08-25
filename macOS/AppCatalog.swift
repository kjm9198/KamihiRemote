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
        let resolved = resolve(bundleIdentifier: bundleIdentifier, catalogPath: catalogPath)
        guard let target = resolved.url else {
            return (false, "App not found (\(bundleIdentifier))")
        }

        // Finder: opening the home folder reliably brings Finder forward.
        if resolved.bundleIdentifier == "com.apple.finder" {
            let home = URL(fileURLWithPath: NSHomeDirectory())
            let opened = NSWorkspace.shared.open(home)
            if opened {
                if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                    _ = finder.activate()
                }
                return (true, "Opened")
            }
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == resolved.bundleIdentifier }) {
            let activated = running.activate()
            if activated {
                return (true, "Opened")
            }
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: target, configuration: configuration) { app, error in
                if let error {
                    continuation.resume(returning: (false, error.localizedDescription))
                } else if app != nil {
                    continuation.resume(returning: (true, "Opened"))
                } else {
                    // openApplication can finish without an app ref even when launch worked.
                    let running = NSWorkspace.shared.runningApplications.contains {
                        $0.bundleIdentifier == resolved.bundleIdentifier
                    }
                    continuation.resume(returning: (running, running ? "Opened" : "Launch did not complete"))
                }
            }
        }
    }

    private static func resolve(bundleIdentifier: String, catalogPath: String?) -> (bundleIdentifier: String, url: URL?) {
        let aliases: [String: [String]] = [
            "com.apple.finder": ["com.apple.finder"],
            "com.openai.chat": ["com.openai.chat"],
            "com.todesktop.230313mzl4w4u92": [
                "com.todesktop.230313mzl4w4u92",
                "com.cursor.Cursor",
                "com.anysphere.cursor"
            ]
        ]
        let candidates = aliases[bundleIdentifier] ?? [bundleIdentifier]
        let workspace = NSWorkspace.shared
        for id in candidates {
            if let url = workspace.urlForApplication(withBundleIdentifier: id) {
                return (id, url)
            }
        }
        if let catalogPath {
            let url = URL(fileURLWithPath: catalogPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return (bundleIdentifier, url)
            }
        }
        // Name-based fallback for Cursor / ChatGPT installs.
        let nameHints: [(String, String)] = [
            ("com.todesktop.230313mzl4w4u92", "Cursor"),
            ("com.openai.chat", "ChatGPT"),
            ("com.apple.finder", "Finder")
        ]
        if let hint = nameHints.first(where: { $0.0 == bundleIdentifier }) {
            let paths = [
                "/Applications/\(hint.1).app",
                "/System/Applications/\(hint.1).app",
                "/System/Library/CoreServices/\(hint.1).app",
                NSHomeDirectory() + "/Applications/\(hint.1).app"
            ]
            for path in paths where FileManager.default.fileExists(atPath: path) {
                return (bundleIdentifier, URL(fileURLWithPath: path))
            }
        }
        return (bundleIdentifier, nil)
    }
}
