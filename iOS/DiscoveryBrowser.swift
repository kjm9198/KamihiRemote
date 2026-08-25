import Foundation
import Network

struct DiscoveredHost: Identifiable, Equatable {
    var id: String { hostID }
    var hostID: String
    var name: String
    var address: String
    var port: UInt16
    var tcpPort: UInt16

    var isResolved: Bool {
        NetworkEndpoint.looksLikeNumericHost(address)
    }
}

final class DiscoveryBrowser: ObservableObject {
    @Published private(set) var hosts: [DiscoveredHost] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "kamihi.bonjour.browser")

    func start() {
        stop()
        let descriptor = NWBrowser.Descriptor.bonjour(type: RemoteConstants.bonjourType, domain: RemoteConstants.bonjourDomain)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: descriptor, using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results)
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    func stopIfNeeded() {
        stop()
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        var discovered: [DiscoveredHost] = []
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }
            var hostID = name
            var tcpPort = RemoteConstants.defaultTCPPort
            var udpPort = RemoteConstants.defaultUDPPort
            if case .bonjour(let records) = result.metadata {
                hostID = records["id"] ?? name
                if let value = records["tcp"], let parsed = UInt16(value) { tcpPort = parsed }
                if let value = records["udp"], let parsed = UInt16(value) { udpPort = parsed }
            }
            discovered.append(
                DiscoveredHost(
                    hostID: hostID,
                    name: name,
                    address: "",
                    port: udpPort,
                    tcpPort: tcpPort
                )
            )
            resolve(result, hostID: hostID, displayName: name, tcpPort: tcpPort, udpPort: udpPort)
        }
        DispatchQueue.main.async {
            let previous = Dictionary(uniqueKeysWithValues: self.hosts.map { ($0.hostID, $0) })
            self.hosts = discovered.map { host in
                var merged = host
                if let existing = previous[host.hostID], existing.isResolved {
                    merged.address = existing.address
                    merged.tcpPort = existing.tcpPort
                }
                return merged
            }
        }
    }

    private func resolve(_ result: NWBrowser.Result, hostID: String, displayName: String, tcpPort: UInt16, udpPort: UInt16) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let connection = NWConnection(to: result.endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let address = NetworkEndpoint.hostString(from: connection.currentPath?.remoteEndpoint) {
                    let resolvedPort: UInt16
                    if case .hostPort(_, let port) = connection.currentPath?.remoteEndpoint {
                        resolvedPort = UInt16(port.rawValue)
                    } else {
                        resolvedPort = tcpPort
                    }
                    let resolved = DiscoveredHost(
                        hostID: hostID,
                        name: displayName,
                        address: address,
                        port: udpPort,
                        tcpPort: resolvedPort
                    )
                    DispatchQueue.main.async {
                        var hosts = self?.hosts ?? []
                        hosts.removeAll { $0.hostID == hostID }
                        hosts.insert(resolved, at: 0)
                        self?.hosts = hosts
                    }
                }
                connection.cancel()
            }
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: queue)
    }
}
