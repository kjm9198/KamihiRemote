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
    @Published var lastTestResultText = ""
    @Published var isTestingAction = false

    private var cancellables = Set<AnyCancellable>()
    private let hostID = DeviceIdentity.deviceID
    private let keys = DeviceKeyPair.loadOrCreate(account: "mac-identity")
    private var failedAttempts = 0
    private var authenticatedSessions: [ObjectIdentifier: String] = [:]

    init() {
        let stored = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
        pairingCode = PairingSecret.isValid(stored) ? stored : PairingSecret.generate()
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")
        launchAtLogin = (try? SMAppService.mainApp.status == .enabled) ?? false

        server.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        tcp.onCommand = { [weak self] command, connection in
            Task { @MainActor in
                self?.handleReliable(command, connection: connection)
            }
        }
        tcp.onDisconnect = { [weak self] connection in
            Task { @MainActor in
                self?.authenticatedSessions[ObjectIdentifier(connection)] = nil
                InputEngine.releaseAll()
                KeyboardGamepad.shared.reset()
            }
        }

        server.onUserAction = { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(80))
                guard Task.isCancelled == false else { return }
                self?.checkAndBroadcastFocusedText()
            }
        }

        server.start(pairingCode: pairingCode)
        tcp.start(pairingCode: pairingCode)
        advertise()
        accessibility.refresh()
        refreshAddress()
        refreshQR()
        RemotePacket.runSelfChecks()
        _ = SessionCrypto.runSelfChecks()
        NotificationCenter.default.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                InputEngine.releaseAll()
            }
        }
        NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advertise()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.broadcastActiveApp()
                try? await Task.sleep(for: .milliseconds(100))
                guard Task.isCancelled == false else { return }
                self?.checkAndBroadcastFocusedText()
            }
        }
    }

    func checkAndBroadcastFocusedText() {
        let snapshot = FocusedTextReader.snapshot()
        tcp.broadcast(.focusedText(status: snapshot.status, value: snapshot.value), token: pairingCode)
    }

    func broadcastActiveApp(to connection: TCPConnection? = nil) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        let name = frontApp.localizedName ?? "Unknown"
        let command = RemoteCommand.activeApp(bundleID: bundleID, name: name)
        if let connection {
            tcp.send(command, token: pairingCode, to: connection)
        } else {
            tcp.broadcast(command, token: pairingCode)
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
        tcp.updatePairingCode(pairingCode)
        refreshQR()
    }

    func approvePending() {
        guard let pending = pendingPairing else { return }
        let pubData = Data(base64Encoded: pending.publicKey) ?? Data()
        TrustedPeerStore.upsert(
            TrustedPeer(deviceID: pending.deviceID, displayName: pending.deviceName, publicKey: pubData, lastUsed: Date())
        )
        trustedDevices = TrustedPeerStore.load()
        let establishedSession = completeHandshake(to: pending.connection, deviceName: pending.deviceName, peerPublicKey: pubData)
        let macPub = keys.publicKeyData.base64EncodedString()
        tcp.send(.pairDecision(ok: true, deviceID: pending.deviceID, sessionMaterial: "\(establishedSession):\(macPub)"), token: pairingCode, to: pending.connection)
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

    func testSystemAction(_ action: SystemAction) {
        isTestingAction = true
        lastTestResultText = "Testing \(action.title)..."
        Task { @MainActor in
            let (ok, msg) = await InputEngine.performReporting(action)
            self.lastTestResultText = "\(action.title): \(ok ? "PASS ✓" : "FAIL ✗") (\(msg))"
            self.isTestingAction = false
        }
    }

    func toggle() {
        if server.isRunning {
            advertiser.stop()
            tcp.stop()
            server.stop()
            authenticatedSessions.removeAll()
            InputEngine.releaseAll()
        } else {
            refreshAddress()
            server.start(pairingCode: pairingCode)
            tcp.start(pairingCode: pairingCode)
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
        advertiser.start(
            name: Host.current().localizedName ?? "Mac",
            hostID: hostID,
            tcpPort: RemoteConstants.defaultTCPPort,
            udpPort: RemoteConstants.defaultUDPPort
        )
    }

    @discardableResult
    private func completeHandshake(to connection: TCPConnection, deviceName: String, peerPublicKey: Data? = nil) -> String {
        tcp.markAuthenticated(connection)
        connectedDeviceName = deviceName
        let connectionID = ObjectIdentifier(connection)

        if let establishedSession = authenticatedSessions[connectionID] {
            sessionID = establishedSession
            if let peerPub = peerPublicKey, !peerPub.isEmpty {
                let upgradedKey = try? SessionCrypto.deriveSessionKey(
                    ourPrivate: keys.privateKey,
                    peerPublic: peerPub,
                    salt: Data(establishedSession.utf8)
                )
                server.updateSession(establishedSession, sessionKey: upgradedKey)
            }
            return establishedSession
        }

        let establishedSession = UUID().uuidString
        sessionID = establishedSession
        authenticatedSessions[connectionID] = establishedSession

        var sessionKey: SymmetricKey?
        if let peerPub = peerPublicKey, !peerPub.isEmpty {
            sessionKey = try? SessionCrypto.deriveSessionKey(
                ourPrivate: keys.privateKey,
                peerPublic: peerPub,
                salt: Data(establishedSession.utf8)
            )
        } else if let peer = TrustedPeerStore.load().first(where: { $0.displayName == deviceName }), !peer.publicKey.isEmpty {
            sessionKey = try? SessionCrypto.deriveSessionKey(
                ourPrivate: keys.privateKey,
                peerPublic: peer.publicKey,
                salt: Data(establishedSession.utf8)
            )
        }

        server.updateSession(establishedSession, sessionKey: sessionKey)
        tcp.send(
            .helloAck(
                sessionID: establishedSession,
                hostName: Host.current().localizedName ?? "Mac",
                hostID: hostID,
                realtimePort: RemoteConstants.defaultUDPPort
            ),
            token: pairingCode,
            to: connection
        )
        tcp.send(.pairAck(ok: true, sessionID: establishedSession), token: pairingCode, to: connection)
        broadcastActiveApp(to: connection)
        return establishedSession
    }

    private func handleReliable(_ command: RemoteCommand, connection: TCPConnection) {
        switch command {
        case .hello(let deviceID, let deviceName, _):
            connectedDeviceName = deviceName
            let peerPub = TrustedPeerStore.load().first(where: { $0.deviceID == deviceID })?.publicKey
            completeHandshake(to: connection, deviceName: deviceName, peerPublicKey: peerPub)

        case .pair(let code, let deviceID):
            guard PairingSecret.matches(code, pairingCode) else {
                failedAttempts += 1
                tcp.send(.pairAck(ok: false, sessionID: sessionID), token: pairingCode, to: connection)
                return
            }
            connectedDeviceName = connectedDeviceName.isEmpty ? "iPhone" : connectedDeviceName
            let peerPub = TrustedPeerStore.load().first(where: { $0.deviceID == deviceID })?.publicKey
            completeHandshake(to: connection, deviceName: connectedDeviceName, peerPublicKey: peerPub)

        case .pairRequest(let deviceID, let deviceName, let publicKey, let code):
            guard PairingSecret.matches(code, pairingCode),
                  let pubData = Data(base64Encoded: publicKey),
                  pubData.isEmpty == false else {
                failedAttempts += 1
                tcp.send(.pairDecision(ok: false, deviceID: deviceID, sessionMaterial: "-"), token: pairingCode, to: connection)
                return
            }

            TrustedPeerStore.upsert(
                TrustedPeer(deviceID: deviceID, displayName: deviceName, publicKey: pubData, lastUsed: Date())
            )
            trustedDevices = TrustedPeerStore.load()
            let establishedSession = completeHandshake(to: connection, deviceName: deviceName, peerPublicKey: pubData)
            let macPub = keys.publicKeyData.base64EncodedString()
            tcp.send(
                .pairDecision(ok: true, deviceID: deviceID, sessionMaterial: "\(establishedSession):\(macPub)"),
                token: pairingCode,
                to: connection
            )

        case .requestAppList:
            let apps = AppCatalog.launchableApplications()
            tcp.send(.appListBegin(count: apps.count), token: pairingCode, to: connection)
            for app in apps.prefix(350) {
                tcp.send(.appEntry(name: app.displayName, bundleID: app.bundleIdentifier), token: pairingCode, to: connection)
            }
            tcp.send(.appListEnd, token: pairingCode, to: connection)

        case .requestActiveApp:
            broadcastActiveApp(to: connection)

        case .heartbeat(let id, let timestamp):
            tcp.send(.heartbeatAck(id: id, timestamp: timestamp), token: pairingCode, to: connection)

        case .releaseAll:
            InputEngine.releaseAll()

        case .revokeDevice(let deviceID):
            revokeDevice(deviceID)

        case .syncControllerMapping(let mapping):
            KeyboardGamepad.shared.mapping = mapping
            kamihiHostLog("Kamihi updated controller mapping profile: \(mapping.profile.rawValue)")

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

    private func executeAcknowledged(id: String, command: RemoteCommand, connection: TCPConnection) async {
        if case .requestFocusedText = command {
            sendFocusedText(to: connection)
            tcp.send(.actionAck(id: id, success: true, message: "Requested"), token: pairingCode, to: connection)
            return
        }
        let (ok, message) = await InputEngine.applyReporting(command)
        tcp.send(.actionAck(id: id, success: ok, message: message), token: pairingCode, to: connection)
    }

    private func sendFocusedText(to connection: TCPConnection) {
        let snapshot = FocusedTextReader.snapshot()
        tcp.send(.focusedText(status: snapshot.status, value: snapshot.value), token: pairingCode, to: connection)
    }
}

struct PendingPairing {
    var deviceID: String
    var deviceName: String
    var publicKey: String
    var code: String
    var connection: TCPConnection
}