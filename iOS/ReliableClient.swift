import Foundation
import Network

final class ReliableClient {
    var onCommand: ((RemoteCommand) -> Void)?
    var onState: ((NWConnection.State) -> Void)?
    var onRTT: ((Int) -> Void)?
    var onPathResolved: ((String) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "kamihi.tcp.client", qos: .userInitiated)
    private var buffer = Data()
    private var pairingCode = ""
    private var heartbeat: DispatchSourceTimer?
    private var heartbeatID: UInt64 = 0
    private var pendingHeartbeat: (UInt64, Date)?
    private var pendingCommands: [RemoteCommand] = []
    private var isReady = false

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
        stop()
        self.pairingCode = pairingCode
        isReady = false
        pendingCommands.removeAll()
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            self.queue.async {
                switch state {
                case .ready:
                    self.isReady = true
                    if let host = NetworkEndpoint.hostString(from: connection.currentPath?.remoteEndpoint) {
                        self.onPathResolved?(host)
                    }
                    self.flushPending()
                    self.startHeartbeat()
                case .waiting, .failed, .cancelled:
                    self.isReady = false
                    self.heartbeat?.cancel()
                    self.heartbeat = nil
                default:
                    break
                }
                self.onState?(state)
            }
        }
        connection.start(queue: queue)
        receive(from: connection)
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.isReady {
                self.write(command)
            } else {
                // Keep only a bounded amount of reliable work while reconnecting.
                // Never let stale commands grow without limit.
                if self.pendingCommands.count >= 64 {
                    self.pendingCommands.removeFirst(self.pendingCommands.count - 63)
                }
                self.pendingCommands.append(command)
            }
        }
    }

    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        pendingHeartbeat = nil
        pendingCommands.removeAll()
        isReady = false
    }

    private func flushPending() {
        guard isReady else { return }
        let queued = pendingCommands
        pendingCommands.removeAll()
        queued.forEach(write)
    }

    private func write(_ command: RemoteCommand) {
        guard let connection, isReady else {
            pendingCommands.append(command)
            return
        }
        let data = RemotePacket.encodeV1(token: pairingCode, command: command)
        connection.send(content: data, completion: .contentProcessed { [weak self, weak connection] error in
            guard let self, let connection else { return }
            if let error {
                self.queue.async {
                    self.handleBrokenConnection(connection, error: error)
                }
            }
        })
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.4, repeating: RemoteConstants.heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.isReady else { return }
            self.heartbeatID += 1
            let id = self.heartbeatID
            self.pendingHeartbeat = (id, Date())
            self.write(.heartbeat(id: id, timestamp: Date().timeIntervalSince1970))
        }
        timer.resume()
        heartbeat = timer
    }

    private func receive(from sourceConnection: NWConnection) {
        sourceConnection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak sourceConnection] data, _, isComplete, error in
            guard let self, let sourceConnection else { return }
            self.queue.async {
                // Ignore callbacks from a connection that has already been replaced.
                guard self.connection === sourceConnection else { return }

                if let data, !data.isEmpty {
                    self.buffer.append(data)
                    self.drain()
                }

                if let error {
                    self.handleBrokenConnection(sourceConnection, error: error)
                    return
                }

                if isComplete {
                    self.handleBrokenConnection(sourceConnection, error: .posix(.ECONNRESET))
                    return
                }

                if self.connection === sourceConnection {
                    self.receive(from: sourceConnection)
                }
            }
        }
    }

    private func handleBrokenConnection(_ broken: NWConnection, error: NWError) {
        guard connection === broken else { return }
        isReady = false
        heartbeat?.cancel()
        heartbeat = nil
        pendingHeartbeat = nil
        broken.stateUpdateHandler = nil
        broken.cancel()
        connection = nil
        onState?(.failed(error))
    }

    private func drain() {
        while let range = buffer.firstRange(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            switch RemotePacket.parse(line) {
            case .success(_, let command, _, _, _, _):
                if case .heartbeatAck(let id, _) = command, pendingHeartbeat?.0 == id {
                    let ms = Int(Date().timeIntervalSince(pendingHeartbeat?.1 ?? Date()) * 1000)
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
