import Foundation

struct GestureBindings: Codable, Equatable {
    /// Finger swipe LEFT → Desktop on the left (Control+Left)
    var threeFingerLeft: SystemAction = .previousDesktop
    /// Finger swipe RIGHT → Desktop on the right (Control+Right)
    var threeFingerRight: SystemAction = .nextDesktop
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
    var smoothingEnabled = false
    var naturalScrolling = true
    var scrollSpeed = 1.0
    var scrollFeel: ScrollFeel = .macLike
    var scrollMomentum = 0.93
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
    var presentationPointerStyle: PresentationPointerStyle = .laser
    var showDeveloperDiagnostics = false
    var autoConnect = true
    var lastHostID: String?
    var bindings = GestureBindings()
    var alwaysShowPointerPad = true
    var pinchEnabled = true
    var pinchInShortcut = "cmd+-"
    var pinchOutShortcut = "cmd+="
    var pinchThreshold = 0.12
    var preferredTransport: TransportKind = .lan
    var automaticTransport = true
    var controllerLayout: ControllerLayout = .standard
    var gameMapping: GameMapping = .fps
    var controllerProfile: ControllerProfile = .mac
    var controllerMapping: ControllerMapping = .mac
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

    static let storageKey = "appPreferences.v6"

    static func load() -> AppPreferences {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = decodeFlexible(data) {
            var prefs = decoded
            prefs.bindings.threeFingerLeft = .previousDesktop
            prefs.bindings.threeFingerRight = .nextDesktop
            prefs.twoFingerSecondaryClick = true
            return prefs
        }

        for legacyKey in ["appPreferences.v5", "appPreferences.v4", "appPreferences.v3", "appPreferences.v2"] {
            if let data = UserDefaults.standard.data(forKey: legacyKey),
               var migrated = decodeFlexible(data) {
                migrated.tapToClick = true
                migrated.twoFingerSecondaryClick = true
                migrated.smoothingEnabled = false
                migrated.pinchEnabled = true
                migrated.bindings.threeFingerLeft = .previousDesktop
                migrated.bindings.threeFingerRight = .nextDesktop
                migrated.showDeveloperDiagnostics = false
                migrated.save()
                return migrated
            }
        }

        return AppPreferences()
    }

    private static func decodeFlexible(_ data: Data) -> AppPreferences? {
        if let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            return decoded
        }
        guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if object["pinchEnabled"] == nil { object["pinchEnabled"] = true }
        if object["tapToClick"] == nil { object["tapToClick"] = true }
        guard let repaired = try? JSONSerialization.data(withJSONObject: object),
              let decoded = try? JSONDecoder().decode(AppPreferences.self, from: repaired)
        else { return nil }
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
        case shortcut, openApp, openURL, system, presentation, media, dictate
    }

    /// Agent / editing focused default deck.
    static let defaultLayout: [DeckButton] = [
        .init(id: "copy", title: "Copy", symbol: "doc.on.doc", kind: .shortcut, payload: "cmd+c"),
        .init(id: "paste", title: "Paste", symbol: "doc.on.clipboard", kind: .shortcut, payload: "cmd+v"),
        .init(id: "selectAll", title: "Select All", symbol: "selection.pin.in.out", kind: .shortcut, payload: "cmd+a"),
        .init(id: "selectLine", title: "Select Line", symbol: "text.line.first.and.arrowtriangle.forward", kind: .shortcut, payload: "selectLine"),
        .init(id: "cursor", title: "Cursor", symbol: "chevron.left.forwardslash.chevron.right", kind: .openApp, payload: "com.todesktop.230313mzl4w4u92"),
        .init(id: "chatgpt", title: "ChatGPT", symbol: "bubble.left.and.text.bubble.right", kind: .openApp, payload: "com.openai.chat"),
        .init(id: "finder", title: "Finder", symbol: "folder", kind: .openApp, payload: "com.apple.finder"),
        .init(id: "dictate", title: "Dictate", symbol: "mic.fill", kind: .dictate, payload: "prompt"),
        .init(id: "deskL", title: "Desktop ←", symbol: "rectangle.leadinghalf.inset.filled", kind: .system, payload: SystemAction.previousDesktop.rawValue),
        .init(id: "deskR", title: "Desktop →", symbol: "rectangle.trailinghalf.inset.filled", kind: .system, payload: SystemAction.nextDesktop.rawValue),
        .init(id: "mission", title: "Mission", symbol: "square.grid.3x3", kind: .system, payload: SystemAction.missionControl.rawValue),
        .init(id: "undo", title: "Undo", symbol: "arrow.uturn.backward", kind: .shortcut, payload: "cmd+z")
    ]

    static let storageKey = "deckLayout.v2"

    static func load() -> [DeckButton] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DeckButton].self, from: data) {
            return decoded.map(Self.migrated)
        }
        // Force the new agent-oriented layout once; keep v1 only if user already customized v2.
        let layout = defaultLayout
        save(layout)
        return layout
    }

    static func save(_ buttons: [DeckButton]) {
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func migrated(_ button: DeckButton) -> DeckButton {
        var copy = button
        if copy.kind == .openApp {
            switch copy.payload.lowercased() {
            case "safari": copy.payload = "com.apple.Safari"
            case "finder": copy.payload = "com.apple.finder"
            case "music": copy.payload = "com.apple.Music"
            case "chatgpt", "chat gpt": copy.payload = "com.openai.chat"
            case "cursor": copy.payload = "com.todesktop.230313mzl4w4u92"
            default: break
            }
        }
        return copy
    }
}
