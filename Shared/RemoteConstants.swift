import Foundation

enum RemoteConstants {
    static let protocolVersion = 3
    static let protocolVersionString = "3"
    static let defaultUDPPort: UInt16 = 49731
    static let defaultTCPPort: UInt16 = 49732
    static let defaultPort: UInt16 = defaultUDPPort
    static let bonjourType = "_kamihiremote._tcp"
    static let bonjourDomain = "local."
    static let pingInterval: TimeInterval = 0.6
    static let pongTimeout: TimeInterval = 2.0
    static let heartbeatInterval: TimeInterval = 0.6
    static let watchdogTimeout: TimeInterval = 1.8
    static let controllerWatchdog: TimeInterval = 0.18
    static let maxRealtimeHz: Double = 120
    static let controllerHz: Double = 90
    static let telemetryHz: Double = 3
    static let reconnectSchedule: [TimeInterval] = [0.25, 0.5, 1, 2, 4]
    static let maxReconnectDelay: TimeInterval = 4
    static let pairingCodeTTL: TimeInterval = 120
    static let bleServiceUUID = "8A91C4E2-6B17-4F3A-9D80-21C0A6F0KAMI".replacingOccurrences(of: "KAMI", with: "A1B2")
    static let bleAuthUUID = "8A91C4E2-6B17-4F3A-9D81-21C0A6F0A1B2"
    static let bleControlUUID = "8A91C4E2-6B17-4F3A-9D82-21C0A6F0A1B2"
    static let bleRealtimeUUID = "8A91C4E2-6B17-4F3A-9D83-21C0A6F0A1B2"
}

enum PointerPreset: String, CaseIterable, Identifiable, Codable {
    case precision
    case normal
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .precision: return "Precision"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    var sensitivity: Double {
        switch self {
        case .precision: return 0.85
        case .normal: return 1.8
        case .fast: return 2.8
        }
    }

    var acceleration: Double {
        switch self {
        case .precision: return 0.35
        case .normal: return 1.0
        case .fast: return 1.7
        }
    }
}

enum HapticLevel: String, CaseIterable, Identifiable, Codable {
    case off, light, normal
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum OrientationMode: String, CaseIterable, Identifiable, Codable {
    case automatic, portrait, landscape
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ScrollFeel: String, CaseIterable, Identifiable, Codable {
    case macLike, direct, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .macLike: return "Mac-like"
        case .direct: return "Direct"
        case .custom: return "Custom"
        }
    }
}

enum ConnectionQuality: String, Codable {
    case excellent, good, unstable, offline

    var title: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .unstable: return "Unstable"
        case .offline: return "Offline"
        }
    }
}

enum TransportKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case lan
    case peerWiFi
    case bluetooth
    case wired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lan: return "Wi-Fi"
        case .peerWiFi: return "Direct Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .wired: return "Wired"
        }
    }
}

enum SystemAction: String, CaseIterable, Codable, Sendable {
    case none
    case missionControl
    case appExpose
    case previousDesktop
    case nextDesktop
    case showDesktop
    case launchpad
    case playPause
    case customShortcut

    var title: String {
        switch self {
        case .none: return "None"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .previousDesktop: return "Previous Desktop"
        case .nextDesktop: return "Next Desktop"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Launchpad"
        case .playPause: return "Play/Pause"
        case .customShortcut: return "Custom Shortcut"
        }
    }
}

enum PresentationProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case keynote, powerpoint, generic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .keynote: return "Keynote"
        case .powerpoint: return "PowerPoint"
        case .generic: return "Google Slides / Generic"
        }
    }
}

enum PresentationPointerStyle: String, CaseIterable, Identifiable, Codable {
    case laser, halo, spotlight
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MediaAction: String, Codable, Sendable {
    case playPause, next, previous, volumeUp, volumeDown, mute
}

enum PresentationAction: String, Codable, Sendable {
    case next, previous, start, end, black, pointer
}

enum ScrollPhase: String, Codable, Sendable {
    case began
    case changed
    case ended
    case momentumBegan
    case momentumChanged
    case momentumEnded
}

enum ZoomAction: String, Codable, Sendable {
    case `in`, out
}

enum GameMapping: String, CaseIterable, Identifiable, Codable {
    case fps, platformer, racing, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fps: return "FPS"
        case .platformer: return "Platformer"
        case .racing: return "Racing"
        case .custom: return "Custom"
        }
    }
}

enum ControllerLayout: String, CaseIterable, Identifiable, Codable {
    case standard, compact, fps, racing, custom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum PointerMode: String, Codable {
    case macCursor
    case presentationLaser
}
