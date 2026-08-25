import AppKit
import Combine
import Foundation
import Network
import ServiceManagement
import CryptoKit

@MainActor
final class HostSession: ObservableObject {
    let server = UDPServer()
    let tcp = TCPServer()
    let advertiser = BonjourAdvertiser()
    let accessibility = AccessibilityManager()

    @Published var localAddress: String = LocalIPAddress.primaryIPv4() ?? "Unknown"
    @Published private(set) var pairingCode: String
    @Published var launchAtLogin = false
    @Published var sessionID = UUID().uuidString
    @Published var connectedDeviceName = ""
    @Published var pendingPairing: PendingPairing?
    @Published var pairingExpiresAt = Date().addingTimeInterval(RemoteConstants.pairingCodeTTL)
    @Published var trustedDevices: [TrustedPeer] = TrustedPeerStore.load()
    @Published var qrPayload = ""

    private var cancellables = Set<AnyCancellable>()
    private let hostID = DeviceIdentity.deviceID
    private let keys = DeviceKeyPair.loadOrCreate(account: "mac-identity")
    private var failedAttempts = 0

    init() {
        let stored = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
        pairingCode = PairingSecret.isValid(stored) ? stored : PairingSecret.generate()
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")
        launchAtLogin = SMAppService.mainApp.status == .enabled

        server.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        tcp.onCommand = { [weak self] command, connection in
            Task { @MainActor in
                self?.handleReliable(command, connection: connection)
            }
        }
        tcp.onDisconnect = {
            InputEngine.releaseAll()
            KeyboardGamepad.shared.reset()
        }

        server.start(pairingCode: pairingCode)
        tcp.start()
        advertise()
        accessibility.refresh()
        accessibility.promptIfNeeded()
        refreshAddress()
        refreshQR()
        RemotePacket.runSelfChecks()
        _ = SessionCrypto.runSelfChecks()
        NotificationCenter.default.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            InputEngine.releaseAll()
        }
        NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.advertise()
        }
    }

    func refreshAddress() {
        localAddress = LocalIPAddress.primaryIPv4() ?? "Unknown"
    }

    func rotatePairingCode() {
        pairingCode = PairingSecret.generate()
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")
        pairingExpiresAt = Date().addingTimeInterval(RemoteConstants.pairingCodeTTL)
        failedAttempts = 0
        server.updatePairingCode(pairingCode)
        refreshQR()
    }

    func approvePending() {
        guard let pending = pendingPairing else { return }
        let pubData = Data(base64Encoded: pending.publicKey) ?? Data()
        TrustedPeerStore.upsert(
            TrustedPeer(deviceID: pending.deviceID, displayName: pending.deviceName, publicKey: pubData, lastUsed: Date())
        )
        trustedDevices = TrustedPeerStore.load()
        completeHandshake(to: pending.connection, deviceName: pending.deviceName, peerPublicKey: pubData)
        let macPub = keys.publicKeyData.base64EncodedString()
        tcp.send(.pairDecision(ok: true, deviceID: pending.deviceID, sessionMaterial: "\(sessionID):\(macPub)"), token: pairingCode, to: pending.connection)
        connectedDeviceName = pending.deviceName
        pendingPairing = nil
        pairingExpiresAt = Date()
    }

    func denyPending() {
        guard let pending = pendingPairing else { return }
        tcp.send(.pairDecision(ok: false, deviceID: pending.deviceID, sessionMaterial: "-"), token: pairingCode, to: pending.connection)
        tcp.send(.pairAck(ok: false, sessionID: sessionID), token: pairingCode, to: pending.connection)
        pendingPairing = nil
        failedAttempts += 1
    }

    func revokeDevice(_ deviceID: String) {
        TrustedPeerStore.revoke(deviceID)
        trustedDevices = TrustedPeerStore.load()
        InputEngine.releaseAll()
    }

    func refreshQR() {
        let pub = keys.publicKeyData.base64EncodedString()
        qrPayload = "kamihi://pair?host=\(hostID)&code=\(pairingCode)&pub=\(pub)&name=\(Host.current().localizedName ?? "Mac")"
    }

    func testCursor() {
        let result = InputEngine.testNudge(dx: 100)
        let text = "created=\(result.created) posted=\(result.posted) trusted=\(result.trusted) \(Int(result.from.x)),\(Int(result.from.y)) → \(Int(result.to.x)),\(Int(result.to.y))"
        server.recordCursorTest(text, posted: result.posted)
        NSLog("Kamihi cursor test: %@", text)
    }

    func toggle() {
        if server.isRunning {
            advertiser.stop()
            tcp.stop()
            server.stop()
            InputEngine.releaseAll()
        } else {
            refreshAddress()
            server.start(pairingCode: pairingCode)
            tcp.start()
            advertise()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            NSLog("Launch at login failed: %@", error.localizedDescription)
        }
    }

    private func advertise() {
        tcp.advertise(
            name: Host.current().localizedName ?? "Mac",
            hostID: hostID,
            udpPort: RemoteConstants.defaultUDPPort
        )
    }

    private func completeHandshake(to connection: NWConnection, deviceName: String, peerPublicKey: Data? = nil) {
        connectedDeviceName = deviceName
        sessionID = UUID().uuidString
        var sessionKey: SymmetricKey?
        if let peerPub = peerPublicKey, !peerPub.isEmpty {
            sessionKey = try? SessionCrypto.deriveSessionKey(ourPrivate: keys.privateKey, peerPublic: peerPub, salt: Data(sessionID.utf8))
        } else if let peer = TrustedPeerStore.load().first(where: { $0.displayName == deviceName }), !peer.publicKey.isEmpty {
            sessionKey = try? SessionCrypto.deriveSessionKey(ourPrivate: keys.privateKey, peerPublic: peer.publicKey, salt: Data(sessionID.utf8))
        }
        server.updateSession(sessionID, sessionKey: sessionKey)
        tcp.send(
            .helloAck(sessionID: sessionID, hostName: Host.current().localizedName ?? "Mac", hostID: hostID, realtimePort: RemoteConstants.defaultUDPPort),
            token: pairingCode,
            to: connection
        )
        tcp.send(.pairAck(ok: true, sessionID: sessionID), token: pairingCode, to: connection)
    }

    private func handleReliable(_ command: RemoteCommand, connection: NWConnection) {
        switch command {
        case .hello(let deviceID, let deviceName, _):
            connectedDeviceName = deviceName
            if let peer = TrustedPeerStore.load().first(where: { $0.deviceID == deviceID }) {
                completeHandshake(to: connection, deviceName: deviceName, peerPublicKey: peer.publicKey)
            }
        case .pair(let code, let deviceID):
            let fresh = Date() < pairingExpiresAt
            let ok = fresh && PairingSecret.matches(code, pairingCode) && failedAttempts < 8
            if ok, let peer = TrustedPeerStore.load().first(where: { $0.deviceID == deviceID }) {
                completeHandshake(to: connection, deviceName: connectedDeviceName, peerPublicKey: peer.publicKey)
            } else if ok {
                pendingPairing = PendingPairing(deviceID: deviceID, deviceName: connectedDeviceName.isEmpty ? "iPhone" : connectedDeviceName, publicKey: "", code: code, connection: connection)
            } else {
                failedAttempts += 1
                tcp.send(.pairAck(ok: false, sessionID: sessionID), token: pairingCode, to: connection)
            }
        case .pairRequest(let deviceID, let deviceName, let publicKey, let code):
            let fresh = Date() < pairingExpiresAt
            let pubData = Data(base64Encoded: publicKey) ?? Data()
            if let peer = TrustedPeerStore.load().first(where: { $0.deviceID == deviceID }) {
                completeHandshake(to: connection, deviceName: deviceName, peerPublicKey: peer.publicKey)
                let macPub = keys.publicKeyData.base64EncodedString()
                tcp.send(.pairDecision(ok: true, deviceID: deviceID, sessionMaterial: "\(sessionID):\(macPub)"), token: pairingCode, to: connection)
                return
            }
            guard fresh, PairingSecret.matches(code, pairingCode), failedAttempts < 8 else {
                failedAttempts += 1
                tcp.send(.pairDecision(ok: false, deviceID: deviceID, sessionMaterial: "-"), token: pairingCode, to: connection)
                return
            }
            pendingPairing = PendingPairing(deviceID: deviceID, deviceName: deviceName, publicKey: publicKey, code: code, connection: connection)
            NSApp.activate(ignoringOtherApps: true)
        case .requestAppList:
            let apps = AppCatalog.launchableApplications()
            tcp.send(.appListBegin(count: apps.count), token: pairingCode, to: connection)
            for app in apps.prefix(350) {
                tcp.send(.appEntry(name: app.displayName, bundleID: app.bundleIdentifier), token: pairingCode, to: connection)
            }
            tcp.send(.appListEnd, token: pairingCode, to: connection)
        case .heartbeat(let id, let timestamp):
            tcp.send(.heartbeatAck(id: id, timestamp: timestamp), token: pairingCode, to: connection)
        case .releaseAll:
            InputEngine.releaseAll()
        case .revokeDevice(let deviceID):
            revokeDevice(deviceID)
        case .syncControllerMapping(let mapping):
            KeyboardGamepad.shared.mapping = mapping
            NSLog("Kamihi updated controller mapping profile: %@", mapping.profile.rawValue)
        case .requestFocusedText:
            sendFocusedText(to: connection)
        case .action(let id, let inner):
            Task { @MainActor in
                await self.executeAcknowledged(id: id, command: inner, connection: connection)
            }
        default:
            if command.shouldAcknowledge {
                Task { @MainActor in
                    let (ok, message) = await InputEngine.applyReporting(command)
                    NSLog("Kamihi command %@ success=%@ %@", command.name, ok ? "YES" : "NO", message)
                }
            } else {
                _ = InputEngine.apply(command)
            }
        }
    }

    private func executeAcknowledged(id: String, command: RemoteCommand, connection: NWConnection) async {
        if case .requestFocusedText = command {
            sendFocusedText(to: connection)
            tcp.send(.actionAck(id: id, success: true, message: "Requested"), token: pairingCode, to: connection)
            return
        }
        let (ok, message) = await InputEngine.applyReporting(command)
        tcp.send(.actionAck(id: id, success: ok, message: message), token: pairingCode, to: connection)
    }

    private func sendFocusedText(to connection: NWConnection) {
        let snapshot = FocusedTextReader.snapshot()
        tcp.send(.focusedText(status: snapshot.status, value: snapshot.value), token: pairingCode, to: connection)
    }
}

struct PendingPairing {
    var deviceID: String
    var deviceName: String
    var publicKey: String
    var code: String
    var connection: NWConnection
}
