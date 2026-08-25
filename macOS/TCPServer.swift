import Foundation
import Network

final class TCPServer {
    var onCommand: ((RemoteCommand, NWConnection) -> Void)?
    var onDisconnect: (() -> Void)?

    private var listener: NWListener?
    private var advertisedService: NWListener.Service?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]
    private let queue = DispatchQueue(label: "kamihi.tcp.server", qos: .userInitiated)
    private(set) var port = RemoteConstants.defaultTCPPort

    func start() {
        stop()
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener.service = advertisedService
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("Kamihi TCP listener failed: %@", error.localizedDescription)
        }
    }

    func advertise(name: String, hostID: String, udpPort: UInt16) {
        let service = NWListener.Service(
            name: name,
            type: RemoteConstants.bonjourType,
            domain: RemoteConstants.bonjourDomain,
            txtRecord: NWTXTRecord([
                "id": hostID,
                "tcp": "\(port)",
                "udp": "\(udpPort)",
                "proto": RemoteConstants.protocolVersionString
            ])
        )
        advertisedService = service
        listener?.service = service
    }

    func send(_ command: RemoteCommand, token: String, to connection: NWConnection) {
        let data = RemotePacket.encodeV1(token: token, command: command)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        buffers.removeAll()
        InputEngine.releaseAll()
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        buffers[id] = Data()
        connection.start(queue: queue)
        receive(from: connection)
    }

    private func receive(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            let id = ObjectIdentifier(connection)
            if let data, !data.isEmpty {
                self.buffers[id, default: Data()].append(data)
                self.drain(connection)
            }
            if let error {
                NSLog("Kamihi TCP receive error: %@", error.localizedDescription)
                self.drop(connection)
                self.onDisconnect?()
                return
            }
            if isComplete {
                self.drop(connection)
                self.onDisconnect?()
                return
            }
            self.receive(from: connection)
        }
    }

    private func drain(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        guard var buffer = buffers[id] else { return }
        while let range = buffer.firstRange(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let line = String(data: lineData, encoding: .utf8) {
                switch RemotePacket.parse(line) {
                case .success(_, let command, _, _, _, _):
                    onCommand?(command, connection)
                case .failure:
                    break
                }
            }
        }
        buffers[id] = buffer
    }

    private func drop(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connection.cancel()
        connections[id] = nil
        buffers[id] = nil
    }
}
