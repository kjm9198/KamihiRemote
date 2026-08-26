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
    @Published var activeAppBundleID: String = ""
    @Published var activeAppName: String = ""
    @Published var showsQuickConnect = false
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
    private var connectCandidates: [HostIdentity] = []
    private var connectCandidateIndex = 0
    private var connectFallbackWork: DispatchWorkItem?

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
            // Do not restart TCP mid-handshake on every Bonjour refresh — that was
            // cancelling in-flight connects. Only auto-start when idle/reconnecting,
            // or upgrade an unresolved Bonjour attempt once an IP resolves.
            switch self.connectionState {
            case .idle, .reconnecting:
                self.connectIfPossible()
            case .connecting:
                self.upgradeConnectingTargetIfResolved()
            case .connected:
                break
            }
        }.store(in: &cancellables)
        // Do NOT forward UDP packet publishes into the shell — that rebuilt Deck/Settings at 120 Hz.
        tcp.onCommand = { [weak self] command in
            Task { @MainActor [weak self] in self?.handleIncoming(command) }
        }
        tcp.onState = { [weak self] state in
            Task { @MainActor [weak self] in self?.handleTCP(state) }
        }
        tcp.onDead = { [weak self] reason in
            Task { @MainActor [weak self] in self?.handleTCPDeath(reason) }
        }
        tcp.onSendFailure = { [weak self] command, reason in
            Task { @MainActor [weak self] in
                self?.flashAction("\(command.name)\n\(reason)", success: false)
                self?.deckTrace.message = reason
                self?.deckTrace.success = false
                self?.deckTrace.updatedAt = Date()
            }
        }
        tcp.onRTT = { [weak self] ms in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.telemetry.rttMilliseconds = ms
                self.telemetry.quality = ms > 80 ? .unstable : (ms > 25 ? .good : .excellent)
                self.transport.noteLAN(rtt: ms, peerToPeer: true)
                self.telemetry.transport = self.transport.active.title
                self.telemetry.tcpReady = self.tcp.isReady
            }
        }
        tcp.onPathResolved = { [weak self] address in
            Task { @MainActor [weak self] in
                self?.resolvedAddress = address
                self?.configureUDP(host: address)
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.send(.releaseAll)
                self?.sendController(.neutral)
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.connectIfPossible()
            }
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
            case "keyboard", "remote", "trackpad": selectedTab = .trackpad
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
        if case .system = command {
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
            if command == .click || command == .doubleClick {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.requestFocusedText()
                }
            }
            return
        }
        if command == .click || command == .doubleClick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.requestFocusedText()
            }
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

    func pairWithCode(_ code: String, manualIP: String? = nil) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        pairingCode = cleanCode
        if let manualIP {
            let trimmed = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)
            // Never keep a non-numeric "Mac IP" — Quick Connect used to prefill the phone's own address.
            if NetworkEndpoint.looksLikeNumericHost(trimmed) {
                manualAddress = trimmed
            }
        }
        persist()
        beginCandidateConnect(forceRebuild: true)
    }

    func connectDirect(ip: String, port: UInt16 = RemoteConstants.defaultTCPPort, code: String) {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NetworkEndpoint.looksLikeNumericHost(cleanIP) else {
            statusText = "Enter a valid Mac IP address"
            showsQuickConnect = true
            return
        }
        pairingCode = cleanCode
        manualAddress = cleanIP
        manualPort = Int(port == 0 ? RemoteConstants.defaultTCPPort : port)
        persist()

        let identity = HostIdentity(
            hostID: cleanIP,
            displayName: cleanIP,
            pairingSecret: cleanCode,
            lastAddress: cleanIP,
            lastPort: RemoteConstants.defaultUDPPort,
            lastTCPPort: port == 0 ? RemoteConstants.defaultTCPPort : port,
            lastConnected: nil
        )
        connectCandidates = [identity]
        connectCandidateIndex = 0
        connect(to: identity)
    }

    func connectIfPossible() {
        persist()
        engine.preferences = preferences
        Haptics.level = preferences.hapticLevel
        beginCandidateConnect(forceRebuild: connectionState != .connecting)
    }

    func preferredMacAddressHint() -> String {
        if NetworkEndpoint.looksLikeNumericHost(manualAddress) {
            return manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let resolved = browser.hosts.first(where: { $0.isResolved })?.address {
            return resolved
        }
        let paired = PairedHostStore.load()
        if let last = preferences.lastHostID,
           let host = paired.first(where: { $0.hostID == last }),
           NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
            return host.lastAddress
        }
        if let host = paired.first(where: { NetworkEndpoint.looksLikeNumericHost($0.lastAddress) }) {
            return host.lastAddress
        }
        return ""
    }

    private func beginCandidateConnect(forceRebuild: Bool) {
        if forceRebuild || connectCandidates.isEmpty {
            connectCandidates = buildConnectCandidates()
            connectCandidateIndex = 0
        }
        guard let target = connectCandidates.first else {
            if PairingSecret.isValid(pairingCode) {
                statusText = "Looking for nearby Macs — or enter Mac IP"
            } else {
                statusText = "Enter the 6-digit code from your Mac"
            }
            return
        }
        connect(to: target)
    }

    private func buildConnectCandidates() -> [HostIdentity] {
        var candidates: [HostIdentity] = []
        var seen = Set<String>()

        func append(_ host: HostIdentity) {
            let key: String
            if NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
                key = "ip:\(host.lastAddress):\(host.lastTCPPort == 0 ? RemoteConstants.defaultTCPPort : host.lastTCPPort)"
            } else {
                key = "svc:\(host.displayName.isEmpty ? host.lastAddress : host.displayName)"
            }
            guard seen.insert(key).inserted else { return }
            var copy = host
            if PairingSecret.isValid(pairingCode) {
                copy.pairingSecret = pairingCode
            }
            candidates.append(copy)
        }

        for discovered in browser.hosts where discovered.isResolved {
            append(
                HostIdentity(
                    hostID: discovered.hostID,
                    displayName: discovered.name,
                    pairingSecret: pairingCode,
                    lastAddress: discovered.address,
                    lastPort: discovered.port,
                    lastTCPPort: discovered.tcpPort,
                    lastConnected: nil
                )
            )
        }

        let paired = PairedHostStore.load()
        if let last = preferences.lastHostID,
           let host = paired.first(where: { $0.hostID == last }),
           NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
            append(host)
        }
        for host in paired where NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
            append(host)
        }

        let manual = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if NetworkEndpoint.looksLikeNumericHost(manual) {
            append(
                HostIdentity(
                    hostID: manual,
                    displayName: manual,
                    pairingSecret: pairingCode,
                    lastAddress: manual,
                    lastPort: RemoteConstants.defaultUDPPort,
                    lastTCPPort: resolvedManualTCPPort(),
                    lastConnected: nil
                )
            )
        }

        for discovered in browser.hosts where !discovered.isResolved {
            append(
                HostIdentity(
                    hostID: discovered.hostID,
                    displayName: discovered.name,
                    pairingSecret: pairingCode,
                    lastAddress: discovered.name,
                    lastPort: discovered.port,
                    lastTCPPort: discovered.tcpPort,
                    lastConnected: nil
                )
            )
        }

        if let last = preferences.lastHostID,
           let host = paired.first(where: { $0.hostID == last }) {
            append(host)
        }
        for host in paired {
            append(host)
        }

        return candidates
    }

    private func resolvedManualTCPPort() -> UInt16 {
        let port = UInt16(clamping: max(manualPort, 0))
        if port == 0 || port == RemoteConstants.defaultUDPPort {
            return RemoteConstants.defaultTCPPort
        }
        return port
    }

    private func upgradeConnectingTargetIfResolved() {
        guard connectionState == .connecting,
              let activeHost,
              !NetworkEndpoint.looksLikeNumericHost(activeHost.lastAddress),
              let resolved = browser.hosts.first(where: { $0.isResolved })
        else { return }
        connect(to: resolved)
    }

    private func scheduleConnectFallback(reason: String) {
        connectFallbackWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.connectionState == .connecting, self.isConnected == false else { return }
            self.tryNextConnectCandidate(reason: reason)
        }
        connectFallbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func tryNextConnectCandidate(reason: String) {
        connectCandidateIndex += 1
        guard connectCandidateIndex < connectCandidates.count else {
            statusText = reason.isEmpty ? "Couldn’t reach Mac — check Wi‑Fi, Local Network, and PIN" : reason
            connectionState = .idle
            showsQuickConnect = true
            return
        }
        statusText = "Trying another Mac address…"
        connect(to: connectCandidates[connectCandidateIndex])
    }

    func connect(to host: HostIdentity) {
        reconnectWork?.cancel()
        connectFallbackWork?.cancel()
        handlingTransportDeath = false
        activeHost = host
        handshakeSent = false
        resolvedAddress = NetworkEndpoint.looksLikeNumericHost(host.lastAddress) ? host.lastAddress : nil
        pairingCode = host.pairingSecret.isEmpty ? pairingCode : host.pairingSecret
        connectionState = .connecting
        let label = NetworkEndpoint.looksLikeNumericHost(host.lastAddress) ? host.lastAddress : host.displayName
        statusText = "Connecting to \(label.isEmpty ? "Mac" : label)…"
        if NetworkEndpoint.looksLikeNumericHost(host.lastAddress) {
            let port = host.lastTCPPort == 0 ? RemoteConstants.defaultTCPPort : host.lastTCPPort
            tcp.connect(host: host.lastAddress, port: port, pairingCode: pairingCode)
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
        connectFallbackWork?.cancel()
        reconnectWork?.cancel()
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
            if status == .value || status == .secure {
                showsKeyboard = true
            }
        case .activeApp(let bundleID, let name):
            activeAppBundleID = bundleID
            activeAppName = name
        default:
            break
        }
    }

    private func handleTCP(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectFallbackWork?.cancel()
            handlingTransportDeath = false
            telemetry.tcpReady = true
            sendHandshake()
        case .waiting(let error):
            statusText = "Waiting for Mac… \(error.localizedDescription)"
            telemetry.tcpReady = false
            if connectionState == .connected {
                beginReconnect()
            } else if connectionState == .connecting {
                scheduleConnectFallback(reason: error.localizedDescription)
            }
        case .failed:
            telemetry.tcpReady = false
            sendController(.neutral)
            if connectionState == .connecting {
                tryNextConnectCandidate(reason: "Connection failed — try Mac IP from Host window")
            } else if connectionState != .idle {
                beginReconnect()
            }
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
        let isFirstConnectionTransition = connectionState != .connected
        reconnectAttempt = 0
        connectFallbackWork?.cancel()
        handlingTransportDeath = false
        connectionState = .connected
        statusText = "connected"
        showsQuickConnect = false
        engine.syncConnection(true)
        telemetry.quality = .excellent
        telemetry.transport = transport.active.title
        telemetry.tcpReady = tcp.isReady
        browser.stopIfNeeded()

        guard isFirstConnectionTransition else { return }
        Haptics.connect()
        syncControllerConfig()
        send(.requestActiveApp)
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
            Task { @MainActor [weak self] in
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
        tcp.updatePairingCode(pairingCode)
        engine.preferences = preferences
        preferences.save()
        DeckButton.save(deck)
    }
}

enum ConnectionState: String {
    case idle, connecting, connected, reconnecting
}

enum RemoteTab: String, CaseIterable, Identifiable {
    case vibe, trackpad, deck, controller
    var id: String { rawValue }
    var title: String {
        switch self {
        case .vibe: return "Vibe"
        case .trackpad: return "Trackpad"
        case .deck: return "Deck"
        case .controller: return "Gamepad"
        }
    }
}
