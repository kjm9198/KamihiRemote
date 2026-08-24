import AppKit
import Combine
import Foundation
import Network
import ServiceManagement

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

    private var cancellables = Set<AnyCancellable>()
    private let hostID = DeviceIdentity.deviceID

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
        }

        server.start(pairingCode: pairingCode)
        tcp.start()
        advertise()
        accessibility.refresh()
        accessibility.promptIfNeeded()
        refreshAddress()
        RemotePacket.runSelfChecks()
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
        server.updatePairingCode(pairingCode)
        sessionID = UUID().uuidString
        server.updateSession(sessionID)
        InputEngine.releaseAll()
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

    private func handleReliable(_ command: RemoteCommand, connection: NWConnection) {
        switch command {
        case .hello(let deviceID, let deviceName, _):
            connectedDeviceName = deviceName
            sessionID = UUID().uuidString
            server.updateSession(sessionID)
            tcp.send(
                .helloAck(sessionID: sessionID, hostName: Host.current().localizedName ?? "Mac", hostID: hostID, realtimePort: RemoteConstants.defaultUDPPort),
                token: pairingCode,
                to: connection
            )
            _ = deviceID
        case .pair(let code, _):
            let ok = PairingSecret.matches(code, pairingCode)
            if ok {
                server.updateSession(sessionID)
            }
            tcp.send(.pairAck(ok: ok, sessionID: sessionID), token: pairingCode, to: connection)
        case .heartbeat(let id, let timestamp):
            tcp.send(.heartbeatAck(id: id, timestamp: timestamp), token: pairingCode, to: connection)
        case .releaseAll:
            InputEngine.releaseAll()
        default:
            _ = InputEngine.apply(command)
        }
    }
}
