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
    private static let legacyKey = "pairedHosts.v2"
    private static let keychainAccount = "paired-hosts-v2"

    static func load() -> [HostIdentity] {
        if let data = KeychainStore.load(account: keychainAccount) {
            return (try? JSONDecoder().decode([HostIdentity].self, from: data)) ?? []
        }

        // One-time migration from the old UserDefaults representation. HostIdentity
        // includes the pairing secret, so it must not remain in an unprotected
        // preferences plist once the Keychain-backed store is available.
        guard let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let hosts = try? JSONDecoder().decode([HostIdentity].self, from: legacyData)
        else {
            return []
        }
        save(hosts)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return hosts
    }

    static func save(_ hosts: [HostIdentity]) {
        guard let data = try? JSONEncoder().encode(hosts) else { return }
        KeychainStore.save(account: keychainAccount, data: data)
        UserDefaults.standard.removeObject(forKey: legacyKey)
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
