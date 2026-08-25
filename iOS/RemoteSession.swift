import Combine
import Foundation
import Network
import SwiftUI
import UIKit
import CryptoKit

@MainActor
final class RemoteSession: ObservableObject, CommandSending {
    let udp = UDPClient()
    let tcp = ReliableClient()
    let browser = DiscoveryBrowser()
    let engine: TouchInputEngine
    let transport: TransportManager

    @Published var preferences = AppPreferences.load()
    @Published var pairingCode = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
    @Published var manualAddress = UserDefaults.standard.string(forKey: "hostAddress") ?? ""
    @Published var manualPort = UserDefaults.standard.integer(forKey: "hostPort") == 0 ? Int(RemoteConstants.defaultUDPPort) : UserDefaults.standard.integer(forKey: "hostPort")
    @Published var showsSettings = false
    @Published var showsDeckEditor = false
    @Published var showsKeyboard = false
    @Published var showsMedia = false
    @Published var selectedTab: RemoteTab = .trackpad
    @Published var connectionState: ConnectionState = .idle
    @Published var statusText = "Looking for nearby Macs"
    @Published var hostName = ""
    @Published var telemetry = LinkTelemetry()
    @Published var precisionActive = false {
        didSet { engine.precisionActive = precisionActive }
    }
    @Published var pointerMode: PointerMode = .macCursor
    @Published var deck = DeckButton.load()
    @Published var hostApps: [HostAppEntry] = []
    @Published var pendingAppName = ""
    @Published var gestureBanner: String? = nil
    @Published var actionBanner: String? = nil
    @Published var deckTrace = DeckActionTrace()
    @Published var focusedTextStatus: FocusedTextStatus = .unavailable
    @Published var focusedTextValue = ""
    #if DEBUG
    @Published var uiTestShowDeckGallery = false
    #endif

    private var sessionID: String?
    private var sessionKey: SymmetricKey?
    private var activeHost: HostIdentity?
    private var reconnectAttempt = 0
    private var reconnectWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var bannerClearWork: DispatchWorkItem?
    private var actionBannerWork: DispatchWorkItem?
    private var handshakeSent = false
    private var resolvedAddress: String?
    private var lastController: ControllerState = .neutral
    private var collectingApps: [HostAppEntry] = []
    private let keys = DeviceKeyPair.loadOrCreate(account: "iphone-identity")
    private var pendingActions: [String: PendingAction] = [:]
    private var telemetryTimer: Timer?
    private var handlingTransportDeath = false

    private struct PendingAction {
        var title: String
        var started: Date
        var timeout: DispatchWorkItem
    }

    init() {
        engine = TouchInputEngine()
        transport = TransportManager(lanReady: { true })
        engine.attach(self)
        engine.preferences = preferences
        browser.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            if self.connectionState != .connected {
                self.connectIfPossible()
            }
        }.store(in: &cancellables)
        // Do NOT forward UDP packet publishes into the shell — that rebuilt Deck/Settings at 120 Hz.
        tcp.onCommand = { [weak self] command in
            Task { @MainActor in self?.handleIncoming(command) }
        }
        tcp.onState = { [weak self] state in
            Task { @MainActor in self?.handleTCP(state) }
        }
        tcp.onDead = { [weak self] reason in
            Task { @MainActor in self?.handleTCPDeath(reason) }
        }
        tcp.onSendFailure = { [weak self] command, reason in
            Task { @MainActor in
                self?.flashAction("\(command.name)\n\(reason)", success: false)
                self?.deckTrace.message = reason
                self?.deckTrace.success = false
                self?.deckTrace.updatedAt = Date()
            }
        }
        tcp.onRTT = { [weak self] ms in
            Task { @MainActor in
                guard let self else { return }
                self.telemetry.rttMilliseconds = ms
                self.telemetry.quality = ms > 80 ? .unstable : (ms > 25 ? .good : .excellent)
                self.transport.noteLAN(rtt: ms, peerToPeer: true)
                self.telemetry.transport = self.transport.active.title
                self.telemetry.tcpReady = self.tcp.isReady
            }
        }
        tcp.onPathResolved = { [weak self] address in
            Task { @MainActor in
                self?.resolvedAddress = address
                self?.configureUDP(host: address)
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.send(.releaseAll)
            self?.sendController(.neutral)
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.connectIfPossible()
        }
        browser.start()
        if preferences.autoConnect {
            connectIfPossible()
        }
        #if DEBUG
        GestureEngineTests.runSelfChecks()
        _ = SessionCrypto.runSelfChecks()
        applyUITestLaunchOverrides()
        #endif
        transport.noteWiredUnsupported()
        startTelemetryClock()
    }

    #if DEBUG
    private func applyUITestLaunchOverrides() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-KamihiUITestTab"), index + 1 < args.count {
            switch args[index + 1].lowercased() {
            case "controller": selectedTab = .controller
            case "keyboard": selectedTab = .keyboard
            case "deck": selectedTab = .deck
            default: break
            }
        }
        if args.contains("-KamihiUITestKeyboard") {
            showsKeyboard = true
        }
        if args.contains("-KamihiUITestDeckGallery") {
            selectedTab = .deck
            hostApps = [
                HostAppEntry(displayName: "Safari", bundleIdentifier: "com.apple.Safari"),
                HostAppEntry(displayName: "Finder", bundleIdentifier: "com.apple.finder"),
                HostAppEntry(displayName: "Music", bundleIdentifier: "com.apple.Music"),
                HostAppEntry(displayName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            ]
            uiTestShowDeckGallery = true
        }
    }
    #endif

    var isConnected: Bool { connectionState == .connected }

    func send(_ command: RemoteCommand) {
        if case .system(let action) = command {
            flashGesture(label(for: command))
        } else if case .rightClick = command {
            flashGesture("Options / Right Click")
        }
        if pointerMode == .presentationLaser, case .move = command {
            let size = engine.animation.trackpadSize
            let x = engine.stats.x / max(size.width, 1)
            let y = engine.stats.y / max(size.height, 1)
            udp.send(.laser(x: x, y: y))
            return
        }
        if command.isRealtime {
            udp.send(command)
            return
        }
        if command.shouldAcknowledge {
            sendAcknowledged(command, title: label(for: command))
            return
        }
        tcp.send(command)
        telemetry.reliablePackets += 1
        telemetry.lastCommand = command.name
    }

    func sendAcknowledged(_ command: RemoteCommand, title: String) {
        guard tcp.isReady || connectionState == .connected || connectionState == .connecting else {
            flashAction("\(title)\nNot connected", success: false)
            deckTrace = DeckActionTrace(title: title, sent: false, received: false, executed: false, success: false, message: "Not connected", latencyMilliseconds: nil, updatedAt: Date())
            return
        }
        let id = UUID().uuidString
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, let pending = self.pendingActions.removeValue(forKey: id) else { return }
            self.flashAction("\(pending.title)\nNo response from Mac", success: false)
            self.deckTrace = DeckActionTrace(
                title: pending.title,
                sent: true,
                received: false,
                executed: false,
                success: false,
                message: "No ACK",
                latencyMilliseconds: Int(Date().timeIntervalSince(pending.started) * 1000),
                updatedAt: Date()
            )
        }
        pendingActions[id] = PendingAction(title: title, started: Date(), timeout: timeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + RemoteConstants.actionAckTimeout, execute: timeout)
        deckTrace = DeckActionTrace(title: title, sent: true, received: false, executed: false, success: nil, message: "Waiting…", latencyMilliseconds: nil, updatedAt: Date())
        tcp.send(.action(id: id, inner: command))
        telemetry.reliablePackets += 1
        telemetry.lastCommand = title
    }

    private func label(for command: RemoteCommand) -> String {
        switch command {
        case .system(let action):
            switch action {
            case .previousDesktop: return "Desktop ◀"
            case .nextDesktop: return "Desktop ▶"
            case .missionControl: return "Mission Control ▲"
            case .appExpose: return "App Exposé ▼"
            case .showDesktop: return "Show Desktop"
            default: return action.title
            }
        case .rightClick: return "Options / Right Click"
        case .openApp(let id): return id.split(separator: ".").last.map(String.init) ?? id
        case .shortcut(let spec): return spec
        case .openURL: return "Open URL"
        case .media: return "Media"
        case .presentation(let action, _): return action.rawValue.capitalized
        case .typeText: return "Type"
        case .zoom: return "Zoom"
        default: return command.name
        }
    }

    private func flashGesture(_ title: String) {
        gestureBanner = title
        bannerClearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.gestureBanner = nil }
        bannerClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func flashAction(_ text: String, success: Bool) {
        actionBanner = text
        if success { Haptics.gesture() } else { Haptics.rightClick() }
        actionBannerWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.actionBanner = nil }
        actionBannerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    func sendController(_ state: ControllerState) {
        lastController = state
        if isConnected {
            udp.send(.controller(state))
        }
    }

    func leaveController(to tab: RemoteTab) {
        sendController(.neutral)
        selectedTab = tab
    }

    func connectIfPossible() {
        persist()
        engine.preferences = preferences
        Haptics.level = preferences.hapticLevel
        if let host = browser.hosts.first(where: { $0.isResolved }) ?? browser.hosts.first {
            connect(to: host)
            return
        }
        if let last = preferences.lastHostID, let host = PairedHostStore.load().first(where: { $0.hostID == last }) {
            connect(to: host)
            return
        }
        let host = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, PairingSecret.isValid(pairingCode) else {
            statusText = "Looking for nearby Macs"
            return
        }
        connect(to: HostIdentity(hostID: host, displayName: host, pairingSecret: pairingCode, lastAddress: host, lastPort: UInt16(clamping: manualPort), lastTCPPort: RemoteConstants.defaultTCPPort, lastConnected: nil))
    }

    func connect(to host: HostIdentity) {
        reconnectWork?.cancel()
        handlingTransportDeath = false
        activeHost = host
        handshakeSent = false
        resolvedAddress = NetworkEndpoint.looksLikeNumericHost(host.lastAddress) ? host.lastAddress : nil
        pairingCode = host.pairingSecret.isEmpty ? pairingCode : host.pairingSecret
        connectionState = .connecting
        statusText = "Connecting to \(host.displayName)…"
        if NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
            tcp.connect(host: host.lastAddress, port: host.lastTCPPort == 0 ? RemoteConstants.defaultTCPPort : host.lastTCPPort, pairingCode: pairingCode)
            configureUDP(host: host.lastAddress)
        } else {
            let serviceName = host.displayName.isEmpty ? host.lastAddress : host.displayName
            tcp.connect(to: NetworkEndpoint.bonjourService(name: serviceName), pairingCode: pairingCode)
        }
    }

    func connect(to discovered: DiscoveredHost) {
        connect(
            to: HostIdentity(
                hostID: discovered.hostID,
                displayName: discovered.name,
                pairingSecret: pairingCode,
                lastAddress: discovered.isResolved ? discovered.address : discovered.name,
                lastPort: discovered.port,
                lastTCPPort: discovered.tcpPort,
                lastConnected: nil
            )
        )
    }

    func forget(_ hostID: String) {
        PairedHostStore.forget(hostID)
        if activeHost?.hostID == hostID {
            disconnect(reason: "Forgot Mac")
        }
        objectWillChange.send()
    }

    func disconnect(reason: String) {
        send(.releaseAll)
        sendController(.neutral)
        tcp.stop()
        udp.stop()
        sessionID = nil
        sessionKey = nil
        connectionState = .idle
        statusText = reason
        engine.syncConnection(false)
        pointerMode = .macCursor
        telemetry.tcpReady = false
        telemetry.udpConfigured = false
        telemetry.quality = .offline
    }

    func applySettingsAndConnect() {
        persist()
        connectIfPossible()
    }

    func requestFocusedText() {
        sendAcknowledged(.requestFocusedText, title: "Focused text")
    }

    private func handleIncoming(_ command: RemoteCommand) {
        switch command {
        case .helloAck(let session, let name, let hostID, let realtimePort):
            sessionID = session
            hostName = name
            udp.updateSession(session, sessionKey: sessionKey)
            telemetry.sessionShort = String(session.prefix(8))
            if var host = activeHost {
                host.hostID = hostID
                host.displayName = name
                host.lastPort = realtimePort
                if let resolvedAddress {
                    host.lastAddress = resolvedAddress
                }
                host.lastConnected = Date()
                host.pairingSecret = pairingCode
                PairedHostStore.upsert(host)
                preferences.lastHostID = hostID
                preferences.save()
                activeHost = host
            }
            if let resolvedAddress {
                configureUDP(host: resolvedAddress)
            }
            markConnected()
        case .pairAck(let ok, let session):
            if ok {
                sessionID = session
                udp.updateSession(session, sessionKey: sessionKey)
                telemetry.sessionShort = String(session.prefix(8))
                markConnected()
            } else if isConnected == false {
                statusText = "Waiting for Mac approval…"
            }
        case .pairDecision(let ok, _, let material):
            if ok {
                let parts = material.split(separator: ":")
                if parts.count >= 2 {
                    let sess = String(parts[0])
                    let macPubB64 = String(parts[1])
                    if let macPubData = Data(base64Encoded: macPubB64) {
                        let derivedKey = try? SessionCrypto.deriveSessionKey(ourPrivate: keys.privateKey, peerPublic: macPubData, salt: Data(sess.utf8))
                        self.sessionKey = derivedKey
                        self.sessionID = sess
                        udp.updateSession(sess, sessionKey: derivedKey)
                        telemetry.sessionShort = String(sess.prefix(8))
                    }
                }
                markConnected()
            } else {
                statusText = "Mac denied pairing"
            }
        case .pong(let name):
            hostName = name
            markConnected()
        case .appListBegin:
            collectingApps = []
            pendingAppName = ""
        case .appEntry(let name, let bundleID):
            collectingApps.append(HostAppEntry(displayName: name, bundleIdentifier: bundleID))
        case .appListEnd:
            hostApps = collectingApps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .actionAck(let id, let success, let message):
            guard let pending = pendingActions.removeValue(forKey: id) else { return }
            pending.timeout.cancel()
            let ms = Int(Date().timeIntervalSince(pending.started) * 1000)
            deckTrace = DeckActionTrace(
                title: pending.title,
                sent: true,
                received: true,
                executed: success,
                success: success,
                message: message,
                latencyMilliseconds: ms,
                updatedAt: Date()
            )
            if success {
                flashAction("\(pending.title)\n\(message.isEmpty ? "Done" : message)", success: true)
            } else {
                flashAction("\(pending.title)\n\(message.isEmpty ? "Failed" : message)", success: false)
            }
        case .focusedText(let status, let value):
            focusedTextStatus = status
            focusedTextValue = value
        default:
            break
        }
    }

    private func handleTCP(_ state: NWConnection.State) {
        switch state {
        case .ready:
            handlingTransportDeath = false
            telemetry.tcpReady = true
            sendHandshake()
        case .waiting(let error):
            statusText = "Waiting for Mac… \(error.localizedDescription)"
            telemetry.tcpReady = false
            if connectionState == .connected { beginReconnect() }
        case .failed:
            telemetry.tcpReady = false
            sendController(.neutral)
            if connectionState != .idle { beginReconnect() }
        case .cancelled:
            telemetry.tcpReady = false
        default:
            break
        }
    }

    private func handleTCPDeath(_ reason: String) {
        guard handlingTransportDeath == false else { return }
        handlingTransportDeath = true
        telemetry.tcpReady = false
        sendController(.neutral)
        if connectionState != .idle {
            statusText = "TCP lost — \(reason)"
            beginReconnect()
        }
    }

    private func sendHandshake() {
        guard handshakeSent == false else { return }
        handshakeSent = true
        statusText = "Talking to Mac…"
        tcp.send(.hello(deviceID: DeviceIdentity.deviceID, deviceName: UIDevice.current.name, capabilities: "trackpad,keyboard,media,deck,controller,ble"))
        let pub = keys.publicKeyData.base64EncodedString()
        if PairingSecret.isValid(pairingCode) {
            tcp.send(.pair(code: pairingCode, deviceID: DeviceIdentity.deviceID))
            tcp.send(.pairRequest(deviceID: DeviceIdentity.deviceID, deviceName: UIDevice.current.name, publicKey: pub, code: pairingCode))
        } else {
            statusText = "Open Settings to enter the pairing code from your Mac"
        }
    }

    private func configureUDP(host: String) {
        guard NetworkEndpoint.looksLikeNumericHost(host) else { return }
        let port = activeHost?.lastPort == 0 || activeHost?.lastPort == nil ? RemoteConstants.defaultUDPPort : activeHost!.lastPort
        udp.configure(host: host, port: port, pairingCode: pairingCode, sessionID: sessionID, sessionKey: sessionKey)
        telemetry.udpConfigured = true
        if var hostIdentity = activeHost {
            hostIdentity.lastAddress = host
            activeHost = hostIdentity
        }
    }

    func syncControllerConfig() {
        send(.syncControllerMapping(preferences.controllerMapping))
    }

    private func markConnected() {
        reconnectAttempt = 0
        handlingTransportDeath = false
        connectionState = .connected
        statusText = "connected"
        engine.syncConnection(true)
        Haptics.connect()
        telemetry.quality = .excellent
        telemetry.transport = transport.active.title
        telemetry.tcpReady = tcp.isReady
        browser.stopIfNeeded()
        syncControllerConfig()
    }

    private func beginReconnect() {
        engine.syncConnection(false)
        sendController(.neutral)
        connectionState = .reconnecting
        statusText = "Reconnecting…"
        telemetry.reconnects += 1
        telemetry.quality = .unstable
        let delay = RemoteConstants.reconnectSchedule[min(reconnectAttempt, RemoteConstants.reconnectSchedule.count - 1)]
        reconnectAttempt += 1
        let work = DispatchWorkItem { [weak self] in
            self?.handlingTransportDeath = false
            self?.connectIfPossible()
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func startTelemetryClock() {
        let timer = Timer(timeInterval: 1.0 / RemoteConstants.telemetryHz, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.telemetry.realtimePacketsPerSecond = self.udp.realtimePacketsPerSecond
                self.telemetry.tcpReady = self.tcp.isReady
                self.telemetry.udpConfigured = self.udp.isConfigured
                self.telemetry.gestureMode = self.engine.debug.mode
                self.telemetry.fingerCount = self.engine.stats.activeFingers
                if self.tcp.lastHeartbeatAck.timeIntervalSinceReferenceDate > 0 {
                    self.telemetry.lastHeartbeatAge = Date().timeIntervalSince(self.tcp.lastHeartbeatAck)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        telemetryTimer = timer
    }

    private func persist() {
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")
        UserDefaults.standard.set(manualAddress, forKey: "hostAddress")
        UserDefaults.standard.set(manualPort, forKey: "hostPort")
        engine.preferences = preferences
        preferences.save()
        DeckButton.save(deck)
    }
}

enum ConnectionState: String {
    case idle, connecting, connected, reconnecting
}

enum RemoteTab: String, CaseIterable, Identifiable {
    case trackpad, keyboard, deck, controller
    var id: String { rawValue }
    var title: String {
        switch self {
        case .trackpad: return "Trackpad"
        case .keyboard: return "Keyboard"
        case .deck: return "Deck"
        case .controller: return "Controller"
        }
    }
}
