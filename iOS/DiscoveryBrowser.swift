import Foundation
import Network

struct DiscoveredHost: Identifiable, Equatable {
    var id: String { hostID + address + "\(port)" }
    var hostID: String
    var name: String
    var address: String
    var port: UInt16
    var tcpPort: UInt16
}

final class DiscoveryBrowser: ObservableObject {
    @Published private(set) var hosts: [DiscoveredHost] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "kamihi.bonjour.browser")

    func start() {
        stop()
        let descriptor = NWBrowser.Descriptor.bonjour(type: RemoteConstants.bonjourType, domain: RemoteConstants.bonjourDomain)
        let browser = NWBrowser(for: descriptor, using: .tcp)
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
                    address: name,
                    port: udpPort,
                    tcpPort: tcpPort
                )
            )
            resolve(result, hostID: hostID, displayName: name, tcpPort: tcpPort, udpPort: udpPort)
        }
        DispatchQueue.main.async {
            if self.hosts.isEmpty {
                self.hosts = discovered
            }
        }
    }

    private func resolve(_ result: NWBrowser.Result, hostID: String, displayName: String, tcpPort: UInt16, udpPort: UInt16) {
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state, let inner = connection.currentPath?.remoteEndpoint {
                if case .hostPort(let host, let port) = inner {
                    let address = "\(host)".trimmingCharacters(in: CharacterSet(charactersIn: "%[]"))
                    let resolved = DiscoveredHost(
                        hostID: hostID,
                        name: displayName,
                        address: address,
                        port: udpPort,
                        tcpPort: UInt16(port.rawValue)
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
