import Foundation
import Network

final class UDPClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var hostName = ""
    @Published private(set) var statusText = "Enter your Mac’s IP and pairing code"
    @Published private(set) var lastError: String?
    @Published private(set) var packetsSent = 0
    @Published private(set) var movePacketsSent = 0

    private var connection: NWConnection?
    private var pairingCode = ""
    private let queue = DispatchQueue(label: "kamihi.udp.client", qos: .userInteractive)
    private var pingTimer: DispatchSourceTimer?
    private var lastPong = Date.distantPast

    func connect(host: String, port: UInt16, pairingCode: String) {
        stop()
        lastError = nil
        hostName = ""
        isConnected = false
        packetsSent = 0
        movePacketsSent = 0
        self.pairingCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        statusText = "Searching for Mac…"

        guard PairingSecret.isValid(self.pairingCode) else {
            statusText = "Enter the 6-digit pairing code"
            return
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(integerLiteral: RemoteConstants.defaultPort),
            using: .udp
        )
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            self?.queue.async {
                self?.handle(state)
            }
        }
        connection.start(queue: queue)
        receive(on: connection)
        startPing()
        send(.ping)
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            guard let self, PairingSecret.isValid(self.pairingCode) else { return }
            guard let connection = self.connection else { return }
            connection.send(content: RemoteEnvelope.encode(token: self.pairingCode, command: command), completion: .idempotent)
            DispatchQueue.main.async {
                self.packetsSent += 1
                if case .move = command {
                    self.movePacketsSent += 1
                }
            }
        }
    }

    func stop() {
        pingTimer?.cancel()
        pingTimer = nil
        connection?.cancel()
        connection = nil
        pairingCode = ""
        setConnected(false, hostName: "", status: "Searching for Mac…")
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            send(.ping)
        case .waiting:
            setConnected(false, hostName: "", status: "Waiting for Mac…")
        case .failed(let error):
            DispatchQueue.main.async { self.lastError = error.localizedDescription }
            setConnected(false, hostName: "", status: "Couldn’t reach Mac")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                self.handleIncoming(text)
            }
            if error == nil, self.connection === connection {
                self.receive(on: connection)
            }
        }
    }

    private func handleIncoming(_ text: String) {
        for line in text.split(whereSeparator: \.isNewline) {
            guard let command = RemoteCommand.parse(String(line)) else { continue }
            if case .pong(let name) = command {
                lastPong = Date()
                setConnected(true, hostName: name, status: "connected")
            }
        }
    }

    private func startPing() {
        let ping = DispatchSource.makeTimerSource(queue: queue)
        ping.schedule(deadline: .now(), repeating: RemoteConstants.pingInterval)
        ping.setEventHandler { [weak self] in
            self?.send(.ping)
            self?.checkTimeout()
        }
        ping.resume()
        pingTimer = ping
    }

    private func checkTimeout() {
        guard isConnected else { return }
        if Date().timeIntervalSince(lastPong) > RemoteConstants.pongTimeout {
            setConnected(false, hostName: "", status: "Searching for Mac…")
        }
    }

    private func setConnected(_ connected: Bool, hostName: String, status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isConnected = connected
            self.hostName = hostName
            self.statusText = status
        }
    }
}
