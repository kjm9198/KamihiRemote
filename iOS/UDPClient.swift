import Foundation
import Network

final class UDPClient: ObservableObject {
    @Published private(set) var packetsSent = 0
    @Published private(set) var movePacketsSent = 0
    @Published private(set) var realtimePacketsPerSecond = 0

    private var connection: NWConnection?
    private var pairingCode = ""
    private var sessionID: String?
    private var sequence: UInt64 = 0
    private let queue = DispatchQueue(label: "kamihi.udp.client", qos: .userInteractive)
    private var pendingDx = 0.0
    private var pendingDy = 0.0
    private var pendingScrollDx = 0.0
    private var pendingScrollDy = 0.0
    private var hasPendingMove = false
    private var hasPendingScroll = false
    private var flushTimer: DispatchSourceTimer?
    private var movesThisSecond = 0
    private var meterTimer: DispatchSourceTimer?

    func configure(host: String, port: UInt16, pairingCode: String, sessionID: String?) {
        stop()
        self.pairingCode = pairingCode
        self.sessionID = sessionID
        sequence = 0
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: RemoteConstants.defaultUDPPort)!,
            using: parameters
        )
        self.connection = connection
        connection.start(queue: queue)
        startFlush()
        startMeter()
    }

    func updateSession(_ sessionID: String?) {
        queue.async { self.sessionID = sessionID }
    }

    func send(_ command: RemoteCommand) {
        queue.async { [weak self] in
            guard let self else { return }
            switch command {
            case .move(let dx, let dy):
                self.pendingDx += dx
                self.pendingDy += dy
                self.hasPendingMove = true
            case .scroll(let dx, let dy, let phase):
                if phase == .changed {
                    self.pendingScrollDx += dx
                    self.pendingScrollDy += dy
                    self.hasPendingScroll = true
                } else {
                    if self.hasPendingScroll {
                        self.write(.scroll(dx: self.pendingScrollDx, dy: self.pendingScrollDy, phase: .changed))
                        self.pendingScrollDx = 0
                        self.pendingScrollDy = 0
                        self.hasPendingScroll = false
                    }
                    self.write(command)
                }
            case .controller:
                self.write(command)
            default:
                self.write(command)
            }
        }
    }

    func stop() {
        flushTimer?.cancel()
        flushTimer = nil
        meterTimer?.cancel()
        meterTimer = nil
        connection?.cancel()
        connection = nil
        sessionID = nil
        hasPendingMove = false
        hasPendingScroll = false
    }

    private func startFlush() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / RemoteConstants.maxRealtimeHz)
        timer.setEventHandler { [weak self] in
            self?.flushPending()
        }
        timer.resume()
        flushTimer = timer
    }

    private func startMeter() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let count = self.movesThisSecond
            self.movesThisSecond = 0
            DispatchQueue.main.async {
                self.realtimePacketsPerSecond = count
            }
        }
        timer.resume()
        meterTimer = timer
    }

    private func flushPending() {
        if hasPendingMove {
            write(.move(dx: pendingDx, dy: pendingDy))
            pendingDx = 0
            pendingDy = 0
            hasPendingMove = false
            movesThisSecond += 1
        }
        if hasPendingScroll {
            write(.scroll(dx: pendingScrollDx, dy: pendingScrollDy, phase: .changed))
            pendingScrollDx = 0
            pendingScrollDy = 0
            hasPendingScroll = false
        }
    }

    private func write(_ command: RemoteCommand) {
        guard let connection else { return }
        let data: Data
        if let sessionID {
            sequence += 1
            data = RemotePacket.encodeV2(sessionID: sessionID, sequence: sequence, command: command)
        } else if PairingSecret.isValid(pairingCode) {
            data = RemotePacket.encodeV1(token: pairingCode, command: command)
        } else {
            return
        }
        connection.send(content: data, completion: .idempotent)
        DispatchQueue.main.async {
            self.packetsSent += 1
            if case .move = command {
                self.movePacketsSent += 1
            }
        }
    }
}
