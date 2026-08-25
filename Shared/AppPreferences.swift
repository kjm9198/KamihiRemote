import Foundation

struct GestureBindings: Codable, Equatable {
    var threeFingerLeft: SystemAction = .nextDesktop
    var threeFingerRight: SystemAction = .previousDesktop
    var threeFingerUp: SystemAction = .missionControl
    var threeFingerDown: SystemAction = .appExpose
    var fourFingerLeft: SystemAction = .previousDesktop
    var fourFingerRight: SystemAction = .nextDesktop
    var fourFingerUp: SystemAction = .missionControl
    var fourFingerDown: SystemAction = .showDesktop
}

struct AppPreferences: Codable, Equatable {
    var pointerPreset: PointerPreset = .normal
    var customSensitivity: Double = 1.8
    var useCustomSensitivity = false
    var smoothing = 0.28
    var smoothingEnabled = true
    var naturalScrolling = true
    var scrollSpeed = 1.0
    var scrollFeel: ScrollFeel = .macLike
    var scrollMomentum = 0.93
    var tapToClick = false
    var twoFingerSecondaryClick = true
    var hapticLevel: HapticLevel = .normal
    var orientation: OrientationMode = .automatic
    var reduceMotionOverride = false
    var precisionGain = 0.32
    var airMouseEnabled = false
    var airMouseSensitivity = 1.6
    var airMouseDeadZone = 0.04
    var presentationProfile: PresentationProfile = .keynote
    var presentationPointerStyle: PresentationPointerStyle = .laser
    var showDeveloperDiagnostics = false
    var autoConnect = true
    var lastHostID: String?
    var bindings = GestureBindings()
    var alwaysShowPointerPad = true
    var pinchInShortcut = "cmd+-"
    var pinchOutShortcut = "cmd+="
    var pinchThreshold = 0.12
    var preferredTransport: TransportKind = .lan
    var automaticTransport = true
    var controllerLayout: ControllerLayout = .standard
    var gameMapping: GameMapping = .fps
    var stickDeadZone = 0.12
    var stickSensitivity = 1.0
    var controllerHaptics = true

    var effectiveSensitivity: Double {
        useCustomSensitivity ? customSensitivity : pointerPreset.sensitivity
    }

    var effectiveAcceleration: Double {
        pointerPreset.acceleration
    }

    var effectiveScrollDecay: Double {
        switch scrollFeel {
        case .macLike: return 0.93
        case .direct: return 0.0
        case .custom: return min(max(scrollMomentum, 0.7), 0.98)
        }
    }

    var effectiveScrollGain: Double {
        switch scrollFeel {
        case .macLike: return 1.35 * scrollSpeed
        case .direct: return 1.0 * scrollSpeed
        case .custom: return scrollSpeed
        }
    }

    static let storageKey = "appPreferences.v4"

    static func load() -> AppPreferences {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            return decoded
        }

        // v0.4.1 migration: older builds could preserve tap-to-click and the large
        // developer HUD from earlier debugging sessions. Reset only the interaction
        // defaults the user explicitly asked to change, while preserving all other
        // preferences.
        for legacyKey in ["appPreferences.v3", "appPreferences.v2"] {
            if let data = UserDefaults.standard.data(forKey: legacyKey),
               let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
                var migrated = decoded
                migrated.tapToClick = false
                migrated.twoFingerSecondaryClick = true
                migrated.showDeveloperDiagnostics = false
                migrated.save()
                return migrated
            }
        }

        return AppPreferences()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct DeckButton: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var symbol: String
    var kind: Kind
    var payload: String

    enum Kind: String, Codable {
        case shortcut, openApp, openURL, system, presentation, media
    }

    static let defaultLayout: [DeckButton] = [
        .init(id: "safari", title: "Safari", symbol: "safari", kind: .openApp, payload: "com.apple.Safari"),
        .init(id: "finder", title: "Finder", symbol: "folder", kind: .openApp, payload: "com.apple.finder"),
        .init(id: "music", title: "Music", symbol: "music.note", kind: .openApp, payload: "com.apple.Music"),
        .init(id: "copy", title: "Copy", symbol: "doc.on.doc", kind: .shortcut, payload: "cmd+c"),
        .init(id: "paste", title: "Paste", symbol: "doc.on.clipboard", kind: .shortcut, payload: "cmd+v"),
        .init(id: "undo", title: "Undo", symbol: "arrow.uturn.backward", kind: .shortcut, payload: "cmd+z"),
        .init(id: "deskL", title: "Desktop ←", symbol: "rectangle.leadinghalf.inset.filled", kind: .system, payload: SystemAction.previousDesktop.rawValue),
        .init(id: "mission", title: "Mission", symbol: "square.grid.3x3", kind: .system, payload: SystemAction.missionControl.rawValue),
        .init(id: "deskR", title: "Desktop →", symbol: "rectangle.trailinghalf.inset.filled", kind: .system, payload: SystemAction.nextDesktop.rawValue)
    ]

    static func load() -> [DeckButton] {
        guard let data = UserDefaults.standard.data(forKey: "deckLayout.v1"),
              let decoded = try? JSONDecoder().decode([DeckButton].self, from: data)
        else { return defaultLayout }
        return decoded.map(Self.migrated)
    }

    static func save(_ buttons: [DeckButton]) {
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: "deckLayout.v1")
        }
    }

    private static func migrated(_ button: DeckButton) -> DeckButton {
        var copy = button
        if copy.kind == .openApp {
            switch copy.payload.lowercased() {
            case "safari": copy.payload = "com.apple.Safari"
            case "finder": copy.payload = "com.apple.finder"
            case "music": copy.payload = "com.apple.Music"
            default: break
            }
        }
        return copy
    }
}
