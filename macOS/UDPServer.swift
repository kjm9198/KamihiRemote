import Foundation
import Network
import CryptoKit

final class UDPServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var clientConnected = false
    @Published private(set) var clientLabel = ""
    @Published private(set) var lastError: String?
    @Published private(set) var stats = HostPipelineStats()

    var onUserAction: (() -> Void)?

    let port: UInt16 = RemoteConstants.defaultPort
    let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName

    private var pairingCode = ""
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let queue = DispatchQueue(label: "kamihi.udp.server", qos: .userInteractive)
    private var lastPacket = Date.distantPast
    private var lastController = Date.distantPast
    private var timeoutTimer: DispatchSourceTimer?
    private var packetsThisSecond = 0
    private var movesThisSecond = 0
    private var activeSessionID: String?
    private var activeSessionKey: SymmetricKey?
    private var sequenceGate = SequenceGate()

    func start(pairingCode: String) {
        stop()
        self.pairingCode = pairingCode
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListener(state)
            }
            self.listener = listener
            listener.start(queue: queue)
            startTimeoutWatch()
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.isRunning = false
            }
        }
    }

    func updateSession(_ sessionID: String?, sessionKey: SymmetricKey? = nil) {
        queue.async {
            self.activeSessionID = sessionID
            self.activeSessionKey = sessionKey
            self.sequenceGate.reset()
        }
    }

    func updatePairingCode(_ code: String) {
        queue.async {
            self.pairingCode = code
            DispatchQueue.main.async {
                self.clientConnected = false
                self.clientLabel = ""
            }
        }
    }

    func recordCursorTest(_ text: String, posted: Bool) {
        DispatchQueue.main.async {
            self.stats.lastTestResult = text
            if posted {
                self.stats.cgEventsPosted += 1
            }
        }
    }

    func stop() {
        timeoutTimer?.cancel()
        timeoutTimer = nil
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
            self.clientConnected = false
            self.clientLabel = ""
        }
    }

    private func handleListener(_ state: NWListener.State) {
        switch state {
        case .ready:
            DispatchQueue.main.async { self.isRunning = true }
        case .failed(let error):
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.isRunning = false
            }
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        connection.start(queue: queue)
        receive(from: connection)
    }

    private func receive(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, data.isEmpty == false, let text = String(data: data, encoding: .utf8) {
                self.handlePacket(text, from: connection)
            } else if let data, data.isEmpty == false {
                self.reject("invalid UTF-8", from: connection)
            }
            if error == nil {
                self.receive(from: connection)
            } else {
                self.connections[ObjectIdentifier(connection)] = nil
            }
        }
    }

    private func handlePacket(_ text: String, from connection: NWConnection) {
        packetsThisSecond += 1
        noteReceived()

        guard LocalNetworkPolicy.allows(connection) else {
            reject("unauthorized IP", from: connection)
            return
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let raw = String(line)
            recordRaw(raw, from: connection)
            switch RemotePacket.parse(raw, sessionKey: activeSessionKey) {
            case .failure(let reason):
                reject(reason, from: connection, raw: raw)
            case .success(let token, let command, let legacy, let sessionID, let sequence, let isEncrypted):
                let authorized: Bool
                if isEncrypted {
                    authorized = (sessionID == activeSessionID || activeSessionID == nil)
                } else if PairingSecret.matches(token, pairingCode) {
                    // Always accept the temporary pairing code for realtime input.
                    authorized = true
                } else if let activeSessionID, token == activeSessionID || sessionID == activeSessionID {
                    authorized = true
                } else {
                    authorized = false
                }
                guard authorized else {
                    let reason: String
                    if token.isEmpty {
                        reason = "missing pairing code"
                    } else if !PairingSecret.isValid(token), activeSessionID == nil {
                        reason = "missing pairing code"
                    } else {
                        reason = "wrong pairing code"
                    }
                    reject(reason, from: connection, raw: raw, parsed: "Auth: \(token) ✗  \(reason)")
                    continue
                }
                if let sequence, sequenceGate.shouldAccept(sequence) == false {
                    DispatchQueue.main.async { self.stats.droppedStale += 1 }
                    continue
                }
                if legacy {
                    NSLog("Kamihi packet used legacy command-first order: %@", raw)
                }
                lastPacket = Date()
                if command.isController { lastController = Date() }
                accept(command, from: connection, raw: raw, token: token, legacy: legacy, isEncrypted: isEncrypted)
            }
        }
    }

    private func accept(_ command: RemoteCommand, from connection: NWConnection, raw: String, token: String, legacy: Bool, isEncrypted: Bool) {
        var posted = false
        var dxText = "—"
        var dyText = "—"
        let name: String

        switch command {
        case .ping:
            name = "PING"
            connection.send(content: RemoteCommand.pong(hostName: hostName).payload, completion: .idempotent)
        case .pong:
            name = "PONG"
        case .move(let dx, let dy):
            name = "MOVE"
            dxText = RemotePacket.formatCoord(dx)
            dyText = RemotePacket.formatCoord(dy)
            movesThisSecond += 1
            posted = InputEngine.move(dx: dx, dy: dy)
        case .click:
            name = "CLICK"
            posted = InputEngine.click()
            DispatchQueue.main.async { self.onUserAction?() }
        case .doubleClick:
            name = "DOUBLE_CLICK"
            posted = InputEngine.doubleClick()
            DispatchQueue.main.async { self.onUserAction?() }
        case .rightClick:
            name = "RIGHT_CLICK"
            posted = InputEngine.rightClick()
        case .scroll(let dx, let dy, _):
            name = "SCROLL"
            dxText = RemotePacket.formatCoord(dx)
            dyText = RemotePacket.formatCoord(dy)
            posted = InputEngine.apply(command)
        case .mouseDown:
            name = "MOUSE_DOWN"
            posted = InputEngine.mouseDown()
        case .mouseUp:
            name = "MOUSE_UP"
            posted = InputEngine.mouseUp()
            DispatchQueue.main.async { self.onUserAction?() }
        default:
            name = command.name
            posted = InputEngine.apply(command)
        }

        let parsed = parsedSummary(token: token, command: command, name: name, dx: dxText, dy: dyText, legacy: legacy, isEncrypted: isEncrypted)
        let ip = endpointLabel(connection)
        DispatchQueue.main.async {
            self.clientConnected = true
            self.clientLabel = ip
            self.stats.accepted += 1
            self.stats.lastCommand = name
            self.stats.lastDx = dxText
            self.stats.lastDy = dyText
            self.stats.lastPacketAt = Self.stamp()
            self.stats.clientIP = ip
            self.stats.lastRawPacket = raw
            self.stats.lastParsed = parsed
            if name == "MOVE" {
                self.stats.movePackets += 1
            }
            if posted {
                self.stats.cgEventsPosted += 1
            } else if name == "MOVE" || name == "CLICK" || name == "RIGHT_CLICK" || name == "SCROLL" || name == "MOUSE_DOWN" || name == "MOUSE_UP" {
                self.stats.lastRejection = InputEngine.canInjectEvents ? "CGEvent create/post failed" : "Accessibility not trusted"
            }
        }
    }

    private func reject(_ reason: String, from connection: NWConnection, raw: String? = nil, parsed: String? = nil) {
        let ip = endpointLabel(connection)
        NSLog("Kamihi reject: %@ from %@", reason, ip)
        DispatchQueue.main.async {
            self.stats.rejected += 1
            self.stats.lastRejection = reason
            self.stats.lastPacketAt = Self.stamp()
            self.stats.clientIP = ip
            if let raw {
                self.stats.lastRawPacket = raw
            }
            self.stats.lastParsed = parsed ?? "failed: \(reason)"
        }
    }

    private func recordRaw(_ raw: String, from connection: NWConnection) {
        let ip = endpointLabel(connection)
        DispatchQueue.main.async {
            self.stats.lastRawPacket = raw
            self.stats.clientIP = ip
            self.stats.lastPacketAt = Self.stamp()
        }
    }

    private func parsedSummary(token: String, command: RemoteCommand, name: String, dx: String, dy: String, legacy: Bool, isEncrypted: Bool) -> String {
        let extra: String
        switch command {
        case .move, .scroll:
            extra = "  dx: \(dx)  dy: \(dy)"
        default:
            extra = ""
        }
        let encBadge = isEncrypted ? " [AES-GCM] " : " "
        return "Auth: \(token)\(encBadge)✓  Command: \(name) ✓\(extra)\(legacy ? "  (legacy order)" : "")"
    }

    private func noteReceived() {
        DispatchQueue.main.async {
            self.stats.packetsReceived += 1
        }
    }

    private func endpointLabel(_ connection: NWConnection) -> String {
        if case .hostPort(let host, _) = connection.endpoint {
            return "\(host)"
        }
        return "unknown"
    }

    private func startTimeoutWatch() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let rx = self.packetsThisSecond
            let moves = self.movesThisSecond
            self.packetsThisSecond = 0
            self.movesThisSecond = 0
            DispatchQueue.main.async {
                self.stats.packetsPerSecond = rx
                self.stats.movePacketsPerSecond = moves
                if self.clientConnected, Date().timeIntervalSince(self.lastPacket) > RemoteConstants.watchdogTimeout {
                    InputEngine.releaseAll()
                    self.clientConnected = false
                    self.clientLabel = ""
                }
                if self.lastController.timeIntervalSince1970 > 0,
                   Date().timeIntervalSince(self.lastController) > RemoteConstants.controllerWatchdog {
                    KeyboardGamepad.shared.reset()
                    self.lastController = Date.distantPast
                }
            }
        }
        timer.resume()
        timeoutTimer = timer
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
