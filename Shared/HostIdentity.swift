import Foundation

struct HostIdentity: Codable, Equatable, Identifiable, Hashable {
    var id: String { hostID }
    var hostID: String
    var displayName: String
    var pairingSecret: String
    var lastAddress: String
    var lastPort: UInt16
    var lastTCPPort: UInt16
    var lastConnected: Date?
}

struct PairedHostStore {
    private static let key = "pairedHosts.v2"

    static func load() -> [HostIdentity] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HostIdentity].self, from: data)) ?? []
    }

    static func save(_ hosts: [HostIdentity]) {
        if let data = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func upsert(_ host: HostIdentity) {
        var hosts = load().filter { $0.hostID != host.hostID }
        hosts.insert(host, at: 0)
        save(hosts)
    }

    static func forget(_ hostID: String) {
        save(load().filter { $0.hostID != hostID })
    }
}

enum DeviceIdentity {
    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: "deviceID"), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: "deviceID")
        return created
    }

    static var deviceName: String {
        ProcessInfo.processInfo.hostName
    }
}

struct LinkTelemetry: Equatable {
    var realtimePacketsPerSecond = 0
    var reliablePackets = 0
    var droppedStale = 0
    var reconnects = 0
    var rttMilliseconds = 0
    var uptimeSeconds = 0
    var transport = "UDP+TCP"
    var quality: ConnectionQuality = .offline
    var tcpReady = false
    var udpConfigured = false
    var lastHeartbeatAge: TimeInterval = 0
    var sessionShort = "—"
    var lastCommand = "—"
    var gestureMode = "idle"
    var fingerCount = 0
}

struct DeckActionTrace: Equatable {
    var title = ""
    var sent = false
    var received = false
    var executed = false
    var success: Bool?
    var message = ""
    var latencyMilliseconds: Int?
    var updatedAt = Date.distantPast
}
