import Foundation

final class BonjourAdvertiser: NSObject, NetServiceDelegate {
    private var netService: NetService?

    func start(name: String, hostID: String, tcpPort: UInt16, udpPort: UInt16) {
        stop()
        let service = NetService(
            domain: RemoteConstants.bonjourDomain,
            type: RemoteConstants.bonjourType + ".",
            name: name,
            port: Int32(tcpPort)
        )
        let txtDict: [String: Data] = [
            "id": Data(hostID.utf8),
            "tcp": Data("\(tcpPort)".utf8),
            "udp": Data("\(udpPort)".utf8),
            "proto": Data(RemoteConstants.protocolVersionString.utf8)
        ]
        service.setTXTRecord(NetService.data(fromTXTRecord: txtDict))
        service.delegate = self
        service.publish()
        self.netService = service
    }

    func stop() {
        netService?.stop()
        netService = nil
    }

    func netServiceDidPublish(_ sender: NetService) {
        NSLog("Kamihi Bonjour service published: %@", sender.name)
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        NSLog("Kamihi Bonjour service failed to publish: %@", errorDict)
    }
}
