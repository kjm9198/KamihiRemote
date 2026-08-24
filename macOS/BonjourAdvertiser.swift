import Foundation
import Network

final class BonjourAdvertiser {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "kamihi.bonjour.advertise")

    func start(name: String, hostID: String, tcpPort: UInt16, udpPort: UInt16) {
        stop()
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: tcpPort)!)
            listener.service = NWListener.Service(
                name: name,
                type: RemoteConstants.bonjourType,
                domain: RemoteConstants.bonjourDomain,
                txtRecord: NWTXTRecord([
                    "id": hostID,
                    "tcp": "\(tcpPort)",
                    "udp": "\(udpPort)",
                    "proto": RemoteConstants.protocolVersionString
                ])
            )
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("Kamihi Bonjour advertise failed: %@", error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
