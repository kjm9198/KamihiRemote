import Foundation
import Network

protocol MessageTransport: AnyObject {
    var kind: TransportKind { get }
    var isReady: Bool { get }
    var measuredRTT: Int { get }
    func start()
    func stop()
    func send(_ command: RemoteCommand)
}

final class TransportManager: ObservableObject {
    @Published private(set) var active: TransportKind = .lan
    @Published private(set) var fallback: TransportKind?
    @Published private(set) var rttMilliseconds = 0
    @Published private(set) var bluetoothStatus = "Bluetooth transport is not active; no CoreBluetooth transport is registered."
    @Published private(set) var wiredStatus = "Wired transport not available using supported public app APIs in the current architecture."
    @Published private(set) var nativeGamepadStatus = "Blocked pending Apple entitlement"

    let lanReady: () -> Bool
    private var bluetoothReady = false

    init(lanReady: @escaping () -> Bool) {
        self.lanReady = lanReady
    }

    func score(lanRTT: Int, bleRSSI: Int?, peerAvailable: Bool) -> TransportKind {
        if lanRTT > 0 && lanRTT < 25 { return peerAvailable ? .peerWiFi : .lan }
        if bluetoothReady, let rssi = bleRSSI, rssi > -70, lanRTT > 40 { return .bluetooth }
        if peerAvailable { return .peerWiFi }
        return .lan
    }

    func noteLAN(rtt: Int, peerToPeer: Bool) {
        rttMilliseconds = rtt
        active = peerToPeer ? .peerWiFi : .lan
        fallback = bluetoothReady ? .bluetooth : nil
    }

    /// Bluetooth must only become selectable after a real CoreBluetooth transport
    /// has started and reported itself ready. UUID constants alone are not transport.
    func noteBluetoothAvailability(_ available: Bool) {
        bluetoothReady = available
        bluetoothStatus = available
            ? "Bluetooth transport ready"
            : "Bluetooth transport is not active; no CoreBluetooth transport is registered."

        if available == false, fallback == .bluetooth {
            fallback = nil
        }
    }

    func noteWiredUnsupported() {
        wiredStatus = "Wired transport not available using supported public app APIs in the current architecture."
    }
}
