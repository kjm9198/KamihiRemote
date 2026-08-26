import Foundation
import Network

final class ReliableClient {
    var onCommand: ((RemoteCommand) -> Void)?
    var onState: ((NWConnection.State) -> Void)?
    var onRTT: ((Int) -> Void)?
    var onPathResolved: ((String) -> Void)?
    var onDead: ((String) -> Void)?
    var onSendFailure: ((RemoteCommand, String) -> Void)?

    private(set) var isReady = false
    private(set) var lastHeartbeatAck = Date.distantPast
    private(set) var lastFailure = ""

    private static let maxInboundFrameBytes = 64 * 1024

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "kamihi.tcp.client", qos: .userInitiated)
    private var buffer = Data()
    private var pairingCode = ""
    private var heartbeat: DispatchSourceTimer?
    private var heartbeatID: UInt64 = 0
    private var pendingHeartbeat: (UInt64, Date)?
    private var missedHeartbeats = 0
    private var pendingCommands: [RemoteCommand] = []
    private var writeInFlight = false
    private var generation = 0

    func connect(host: String, port: UInt16, pairingCode: String) {
        connect(
            to: .hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: RemoteConstants.defaultTCPPort)!
            ),
            pairingCode: pairingCode
        )
    }

    func connect(to endpoint: NWEndpoint, pairingCode: String) {
        // A reconnect must not discard commands the user issued while the transport
        // was down. Only an explicit stop should clear the queue.
        stop(notify: false, clearPendingCommands: false)
        self.pairingCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        generation += 1
        let capturedGeneration = generation
        isReady = false
        missedHeartbeats = 0
        pendingHeartbeat = nil
        lastFailure = ""
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, self.generation == capturedGeneration else { return }
            switch state {
            case .ready:
                self.isReady = true
                self.missedHeartbeats = 0
                if let host = NetworkEndpoint.hostString(from: connection.currentPath?.remoteEndpoint) {
                    self.onPathResolved?(host)
                }
                self.flushPending()
                self.startHeartbeat()
            case .waiting(let error):
                self.lastFailure = error.localizedDescription
                if self.isReady {
                    self.isReady = false
                    self.writeInFlight = false
                    self.onDead?("waiting: \(error.localizedDescription)")
                }
            case .failed(let error):
                self.markDead("failed: \(error.localizedDescription)", notify: true)
            case .cancelled:
                if self.isReady {
                    self.markDead("cancelled", notify: true)
                }
            default:
                break
            }
            self.onState?(state)
        }
        connection.start(queue: queue)
        receive(generation: capturedGeneration)
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.pendingCommands.count < RemoteConstants.reliableQueueLimit else {
                self.onSendFailure?(command, "Reliable command queue full")
                return
            }
            self.pendingCommands.append(command)
            self.flushPending()
        }
    }

    func stop() {
        stop(notify: false, clearPendingCommands: true)
    }

    private func stop(notify: Bool, clearPendingCommands: Bool) {
        heartbeat?.cancel()
        heartbeat = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        pendingHeartbeat = nil
        writeInFlight = false
        if clearPendingCommands {
            pendingCommands.removeAll()
        }
        let wasReady = isReady
        isReady = false
        if notify, wasReady {
            onDead?("stopped")
        }
    }

    private func markDead(_ reason: String, notify: Bool) {
        guard connection != nil || isReady else { return }
        lastFailure = reason
        heartbeat?.cancel()
        heartbeat = nil
        isReady = false
        writeInFlight = false
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        pendingHeartbeat = nil
        if notify {
            onDead?(reason)
        }
    }

    /// Sends reliable user commands strictly one-at-a-time.
    ///
    /// The command stays at the head of `pendingCommands` until Network.framework
    /// confirms it was processed. If the socket dies while a send is in flight,
    /// the command remains queued and is retried after the reconnect. This keeps
    /// deck actions, typing, and shortcuts ordered instead of silently losing the
    /// command that happened to be crossing the wire when Wi-Fi changed paths.
    private func flushPending() {
        guard isReady,
              writeInFlight == false,
              let connection,
              let command = pendingCommands.first else { return }

        writeInFlight = true
        let capturedGeneration = generation
        let data = RemotePacket.encodeV1(token: pairingCode, command: command)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self,
                  self.generation == capturedGeneration,
                  self.connection != nil else { return }

            self.writeInFlight = false
            if let error {
                // Keep the command at index 0. `markDead` triggers RemoteSession's
                // reconnect path, and `.ready` will call `flushPending()` again.
                self.markDead("send: \(error.localizedDescription)", notify: true)
                return
            }

            if self.pendingCommands.first == command {
                self.pendingCommands.removeFirst()
            }
            self.flushPending()
        })
    }

    /// Heartbeats are connection-health probes rather than user actions. They are
    /// intentionally not added to the retry queue so stale probes cannot delay
    /// real commands after a reconnect.
    private func writeHeartbeat(_ command: RemoteCommand) {
        guard let connection else { return }
        let capturedGeneration = generation
        let data = RemotePacket.encodeV1(token: pairingCode, command: command)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self,
                  self.generation == capturedGeneration,
                  self.connection != nil else { return }
            if let error {
                self.markDead("heartbeat send: \(error.localizedDescription)", notify: true)
            }
        })
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.4, repeating: RemoteConstants.heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.isReady else { return }
            if let pending = self.pendingHeartbeat, Date().timeIntervalSince(pending.1) > RemoteConstants.watchdogTimeout {
                self.missedHeartbeats += 1
                if self.missedHeartbeats >= RemoteConstants.heartbeatMissLimit {
                    self.markDead("heartbeat timeout", notify: true)
                    return
                }
            }
            self.heartbeatID += 1
            let id = self.heartbeatID
            self.pendingHeartbeat = (id, Date())
            self.writeHeartbeat(.heartbeat(id: id, timestamp: Date().timeIntervalSince1970))
        }
        timer.resume()
        heartbeat = timer
    }

    private func receive(generation: Int) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, self.generation == generation else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drain()
                if self.buffer.count > Self.maxInboundFrameBytes {
                    self.buffer.removeAll(keepingCapacity: false)
                    self.markDead("receive frame exceeded \(Self.maxInboundFrameBytes) bytes", notify: true)
                    return
                }
            }
            if let error {
                self.markDead("receive: \(error.localizedDescription)", notify: true)
                return
            }
            if isComplete {
                self.markDead("receive complete", notify: true)
                return
            }
            if self.connection != nil {
                self.receive(generation: generation)
            }
        }
    }

    private func drain() {
        while let range = buffer.firstRange(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            guard lineData.count <= Self.maxInboundFrameBytes else {
                buffer.removeAll(keepingCapacity: false)
                markDead("receive frame exceeded \(Self.maxInboundFrameBytes) bytes", notify: true)
                return
            }
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            switch RemotePacket.parse(line) {
            case .success(let token, let command, _, _, _, _):
                guard PairingSecret.matches(token, pairingCode) else {
                    lastFailure = "Rejected unauthenticated reliable response"
                    continue
                }
                if case .heartbeatAck(let id, _) = command, pendingHeartbeat?.0 == id {
                    let ms = Int(Date().timeIntervalSince(pendingHeartbeat?.1 ?? Date()) * 1000)
                    lastHeartbeatAck = Date()
                    missedHeartbeats = 0
                    onRTT?(max(ms, 0))
                    pendingHeartbeat = nil
                }
                onCommand?(command)
            case .failure:
                break
            }
        }
    }
}
