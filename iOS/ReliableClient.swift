import Foundation
import Network

final class ReliableClient {
    var onCommand: ((RemoteCommand) -> Void)?
    var onState: ((NWConnection.State) -> Void)?
    var onRTT: ((Int) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "kamihi.tcp.client", qos: .userInitiated)
    private var buffer = Data()
    private var pairingCode = ""
    private var heartbeat: DispatchSourceTimer?
    private var heartbeatID: UInt64 = 0
    private var pendingHeartbeat: (UInt64, Date)?

    func connect(host: String, port: UInt16, pairingCode: String) {
        stop()
        self.pairingCode = pairingCode
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: RemoteConstants.defaultTCPPort)!,
            using: parameters
        )
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            self?.onState?(state)
            if case .ready = state {
                self?.startHeartbeat()
            }
        }
        connection.start(queue: queue)
        receive()
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            guard let self, let connection = self.connection else { return }
            let data = RemotePacket.encodeV1(token: self.pairingCode, command: command)
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        pendingHeartbeat = nil
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.4, repeating: RemoteConstants.heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.heartbeatID += 1
            let id = self.heartbeatID
            self.pendingHeartbeat = (id, Date())
            self.send(.heartbeat(id: id, timestamp: Date().timeIntervalSince1970))
        }
        timer.resume()
        heartbeat = timer
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drain()
            }
            if error == nil, isComplete == false, self.connection != nil {
                self.receive()
            }
        }
    }

    private func drain() {
        while let range = buffer.firstRange(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            switch RemotePacket.parse(line) {
            case .success(_, let command, _, _, _):
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
