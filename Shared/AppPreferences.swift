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
    var smoothing = 0.18
    var smoothingEnabled = true
    var naturalScrolling = true
    var scrollSpeed = 1.0
    var tapToClick = true
    var twoFingerSecondaryClick = true
    var hapticLevel: HapticLevel = .normal
    var orientation: OrientationMode = .automatic
    var reduceMotionOverride = false
    var precisionGain = 0.32
    var airMouseEnabled = false
    var airMouseSensitivity = 1.6
    var airMouseDeadZone = 0.04
    var presentationProfile: PresentationProfile = .keynote
    var showDeveloperDiagnostics = false
    var autoConnect = true
    var lastHostID: String?
    var bindings = GestureBindings()

    var effectiveSensitivity: Double {
        useCustomSensitivity ? customSensitivity : pointerPreset.sensitivity
    }

    var effectiveAcceleration: Double {
        pointerPreset.acceleration
    }

    static let storageKey = "appPreferences.v2"

    static func load() -> AppPreferences {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else { return AppPreferences() }
        return decoded
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
        .init(id: "safari", title: "Safari", symbol: "safari", kind: .openApp, payload: "Safari"),
        .init(id: "finder", title: "Finder", symbol: "folder", kind: .openApp, payload: "Finder"),
        .init(id: "music", title: "Music", symbol: "music.note", kind: .openApp, payload: "Music"),
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
        return decoded
    }

    static func save(_ buttons: [DeckButton]) {
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: "deckLayout.v1")
        }
    }
}
