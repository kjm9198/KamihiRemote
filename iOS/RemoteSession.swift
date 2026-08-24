import Combine
import Foundation
import Network
import SwiftUI
import UIKit

@MainActor
final class RemoteSession: ObservableObject, CommandSending {
    let udp = UDPClient()
    let tcp = ReliableClient()
    let browser = DiscoveryBrowser()
    let engine: TouchInputEngine

    @Published var preferences = AppPreferences.load()
    @Published var pairingCode = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
    @Published var manualAddress = UserDefaults.standard.string(forKey: "hostAddress") ?? ""
    @Published var manualPort = UserDefaults.standard.integer(forKey: "hostPort") == 0 ? Int(RemoteConstants.defaultUDPPort) : UserDefaults.standard.integer(forKey: "hostPort")
    @Published var showsSettings = false
    @Published var selectedTab: RemoteTab = .trackpad
    @Published var connectionState: ConnectionState = .idle
    @Published var statusText = "Looking for nearby Macs"
    @Published var hostName = ""
    @Published var telemetry = LinkTelemetry()
    @Published var precisionActive = false {
        didSet { engine.precisionActive = precisionActive }
    }
    @Published var deck = DeckButton.load()

    private var sessionID: String?
    private var activeHost: HostIdentity?
    private var reconnectAttempt = 0
    private var reconnectWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var handshakeSent = false
    private var resolvedAddress: String?

    init() {
        engine = TouchInputEngine()
        engine.attach(self)
        engine.preferences = preferences
        Haptics.level = preferences.hapticLevel
        browser.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        udp.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        tcp.onCommand = { [weak self] command in
            Task { @MainActor in self?.handleIncoming(command) }
        }
        tcp.onState = { [weak self] state in
            Task { @MainActor in self?.handleTCP(state) }
        }
        tcp.onRTT = { [weak self] ms in
            Task { @MainActor in
                self?.telemetry.rttMilliseconds = ms
                self?.telemetry.quality = ms > 80 ? .unstable : (ms > 25 ? .good : .excellent)
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
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.connectIfPossible()
        }
        browser.start()
        if preferences.autoConnect {
            connectIfPossible()
        }
    }

    var isConnected: Bool { connectionState == .connected }

    func send(_ command: RemoteCommand) {
        if command.isRealtime {
            udp.send(command)
        } else {
            tcp.send(command)
        }
    }

    func connectIfPossible() {
        persist()
        engine.preferences = preferences
        Haptics.level = preferences.hapticLevel
        if let last = preferences.lastHostID, let host = PairedHostStore.load().first(where: { $0.hostID == last }) {
            connect(to: host)
            return
        }
        if let discovered = browser.hosts.first {
            connect(to: discovered)
            return
        }
        let host = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, PairingSecret.isValid(pairingCode) else {
            showsSettings = true
            return
        }
        connect(to: HostIdentity(hostID: host, displayName: host, pairingSecret: pairingCode, lastAddress: host, lastPort: UInt16(clamping: manualPort), lastTCPPort: RemoteConstants.defaultTCPPort, lastConnected: nil))
    }

    func connect(to host: HostIdentity) {
        reconnectWork?.cancel()
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
        tcp.stop()
        udp.stop()
        sessionID = nil
        connectionState = .idle
        statusText = reason
        engine.syncConnection(false)
    }

    func applySettingsAndConnect() {
        persist()
        connectIfPossible()
    }

    private func handleIncoming(_ command: RemoteCommand) {
        switch command {
        case .helloAck(let session, let name, let hostID, let realtimePort):
            sessionID = session
            hostName = name
            udp.updateSession(session)
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
                udp.updateSession(session)
                markConnected()
            } else {
                statusText = "Pairing failed"
                showsSettings = true
            }
        case .pong(let name):
            hostName = name
            markConnected()
        default:
            break
        }
    }

    private func handleTCP(_ state: NWConnection.State) {
        switch state {
        case .ready:
            sendHandshake()
        case .waiting(let error):
            statusText = "Waiting for Mac… \(error.localizedDescription)"
            if connectionState == .connected { beginReconnect() }
        case .failed:
            if connectionState != .idle { beginReconnect() }
        case .cancelled:
            break
        default:
            break
        }
    }

    private func sendHandshake() {
        guard handshakeSent == false else { return }
        handshakeSent = true
        statusText = "Talking to Mac…"
        tcp.send(.hello(deviceID: DeviceIdentity.deviceID, deviceName: UIDevice.current.name, capabilities: "trackpad,keyboard,media,deck"))
        if PairingSecret.isValid(pairingCode) {
            tcp.send(.pair(code: pairingCode, deviceID: DeviceIdentity.deviceID))
        } else {
            showsSettings = true
            statusText = "Enter the pairing code from your Mac"
        }
    }

    private func configureUDP(host: String) {
        guard NetworkEndpoint.looksLikeNumericHost(host) else { return }
        let port = activeHost?.lastPort == 0 || activeHost?.lastPort == nil ? RemoteConstants.defaultUDPPort : activeHost!.lastPort
        udp.configure(host: host, port: port, pairingCode: pairingCode, sessionID: sessionID)
        if var hostIdentity = activeHost {
            hostIdentity.lastAddress = host
            activeHost = hostIdentity
        }
    }

    private func markConnected() {
        reconnectAttempt = 0
        connectionState = .connected
        statusText = "connected"
        engine.syncConnection(true)
        Haptics.connect()
        telemetry.quality = .excellent
        telemetry.transport = "UDP+TCP"
    }

    private func beginReconnect() {
        engine.syncConnection(false)
        connectionState = .reconnecting
        statusText = "Reconnecting…"
        telemetry.reconnects += 1
        let delay = RemoteConstants.reconnectSchedule[min(reconnectAttempt, RemoteConstants.reconnectSchedule.count - 1)]
        reconnectAttempt += 1
        let work = DispatchWorkItem { [weak self] in self?.connectIfPossible() }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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
    case trackpad, slides, keyboard, media, deck
    var id: String { rawValue }
}
