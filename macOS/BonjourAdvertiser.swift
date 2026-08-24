import Foundation
import Network

final class BonjourAdvertiser {
    func start(name: String, hostID: String, tcpPort: UInt16, udpPort: UInt16) {
        // Advertising is attached to the TCP listener so we never bind 49732 twice.
    }

    func stop() {}
}
