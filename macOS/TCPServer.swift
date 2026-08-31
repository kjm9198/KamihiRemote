import Foundation
import Darwin

func kamihiHostLog(_ message: String) {
    let line = message + "\n"
    line.withCString { ptr in
        _ = write(STDERR_FILENO, ptr, strlen(ptr))
    }
}

public final class TCPConnection: Hashable, Identifiable {
    public let id = UUID()
    public let fd: Int32
    var buffer = Data()
    var readSource: DispatchSourceRead?

    init(fd: Int32) {
        self.fd = fd
    }

    public static func == (lhs: TCPConnection, rhs: TCPConnection) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func closeSocket() {
        readSource?.cancel()
        readSource = nil
        close(fd)
    }
}

final class TCPServer {
    var onCommand: ((RemoteCommand, TCPConnection) -> Void)?
    var onDisconnect: ((TCPConnection) -> Void)?

    private var serverSock: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var connections: [ObjectIdentifier: TCPConnection] = [:]
    private var handshakeConnections: Set<ObjectIdentifier> = []
    private let queue = DispatchQueue(label: "kamihi.tcp.server", qos: .userInitiated)
    private let maximumFrameBytes = 64 * 1024
    private(set) var port = RemoteConstants.defaultTCPPort
    private var pairingCode = ""

    func start(pairingCode: String) {
        stop()
        self.pairingCode = pairingCode
        queue.async { [weak self] in
            guard let self else { return }
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else {
                kamihiHostLog("Kamihi TCP socket creation failed: errno \(errno)")
                return
            }
            var opt: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &opt, socklen_t(MemoryLayout<Int32>.size))

            var nosigpipe: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(self.port).bigEndian
            addr.sin_addr.s_addr = in_addr_t(0)

            let bindRes = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindRes == 0 else {
                kamihiHostLog("Kamihi TCP socket bind failed: errno \(errno)")
                close(sock)
                return
            }

            guard listen(sock, 32) == 0 else {
                kamihiHostLog("Kamihi TCP socket listen failed: errno \(errno)")
                close(sock)
                return
            }

            self.serverSock = sock
            let source = DispatchSource.makeReadSource(fileDescriptor: sock, queue: self.queue)
            source.setEventHandler { [weak self] in
                guard let self, self.serverSock >= 0 else { return }
                var clientAddr = sockaddr_storage()
                var clientLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
                let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.accept(self.serverSock, $0, &clientLen)
                    }
                }
                guard clientFd >= 0 else { return }
                var clientNosigpipe: Int32 = 1
                setsockopt(clientFd, SOL_SOCKET, SO_NOSIGPIPE, &clientNosigpipe, socklen_t(MemoryLayout<Int32>.size))
                self.accept(clientFd)
            }
            source.setCancelHandler {
                if sock >= 0 {
                    close(sock)
                }
            }
            source.resume()
            self.listenSource = source
            kamihiHostLog("Kamihi TCP listener ready on port \(self.port)")
        }
    }

    func updatePairingCode(_ code: String) {
        queue.async { [weak self] in
            self?.pairingCode = code
        }
    }

    func advertise(name: String, hostID: String, udpPort: UInt16) {
        // Advertising handled by BonjourAdvertiser
    }

    func send(_ command: RemoteCommand, token: String, to connection: TCPConnection) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.connections[ObjectIdentifier(connection)] != nil else { return }
            let data = RemotePacket.encodeV1(token: token, command: command)
            data.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                _ = write(connection.fd, base, data.count)
            }
        }
    }

    func broadcast(_ command: RemoteCommand, token: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let data = RemotePacket.encodeV1(token: token, command: command)
            data.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                for conn in self.connections.values {
                    _ = write(conn.fd, base, data.count)
                }
            }
        }
    }

    func markAuthenticated(_ connection: TCPConnection) {
        queue.async { [weak self] in
            let id = ObjectIdentifier(connection)
            self?.handshakeConnections.insert(id)
        }
    }

    func stop() {
        queue.sync {
            listenSource?.cancel()
            listenSource = nil
            serverSock = -1
            for conn in connections.values {
                conn.closeSocket()
                onDisconnect?(conn)
            }
            connections.removeAll()
            handshakeConnections.removeAll()
            InputEngine.releaseAll()
        }
    }

    private func accept(_ clientFd: Int32) {
        let conn = TCPConnection(fd: clientFd)
        let id = ObjectIdentifier(conn)
        connections[id] = conn

        let readSource = DispatchSource.makeReadSource(fileDescriptor: clientFd, queue: queue)
        conn.readSource = readSource
        readSource.setEventHandler { [weak self, weak conn] in
            guard let self, let conn else { return }
            var buf = [UInt8](repeating: 0, count: 8192)
            let n = read(conn.fd, &buf, buf.count)
            if n > 0 {
                conn.buffer.append(buf, count: n)
                guard self.drain(conn) else { return }

                if conn.buffer.count > self.maximumFrameBytes {
                    NSLog("Kamihi TCP dropped oversized unterminated frame")
                    self.drop(conn)
                    self.onDisconnect?(conn)
                }
            } else {
                self.drop(conn)
                self.onDisconnect?(conn)
            }
        }
        readSource.setCancelHandler {
            close(clientFd)
        }
        readSource.resume()
    }

    @discardableResult
    private func drain(_ connection: TCPConnection) -> Bool {
        let id = ObjectIdentifier(connection)
        while let range = connection.buffer.firstRange(of: Data("\n".utf8)) {
            let lineData = connection.buffer.subdata(in: connection.buffer.startIndex..<range.lowerBound)
            connection.buffer.removeSubrange(connection.buffer.startIndex..<range.upperBound)

            guard lineData.count <= maximumFrameBytes else {
                NSLog("Kamihi TCP dropped oversized frame")
                drop(connection)
                onDisconnect?(connection)
                return false
            }

            if let line = String(data: lineData, encoding: .utf8) {
                switch RemotePacket.parse(line) {
                case .success(let token, let command, _, _, _, _):
                    switch command {
                    case .hello, .pair, .pairRequest:
                        onCommand?(command, connection)
                    default:
                        guard handshakeConnections.contains(id) || PairingSecret.matches(token, pairingCode) else {
                            kamihiHostLog("Kamihi rejected unauthenticated TCP command: \(command.name)")
                            continue
                        }
                        onCommand?(command, connection)
                    }
                case .failure:
                    break
                }
            }
        }
        return true
    }

    private func drop(_ connection: TCPConnection) {
        let id = ObjectIdentifier(connection)
        connection.readSource?.cancel()
        connection.readSource = nil
        connections[id] = nil
        handshakeConnections.remove(id)
    }
}
