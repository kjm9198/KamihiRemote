import Combine
import Foundation

@MainActor
final class HostSession: ObservableObject {
    let server = UDPServer()
    let accessibility = AccessibilityManager()

    @Published var localAddress: String = LocalIPAddress.primaryIPv4() ?? "Unknown"
    @Published private(set) var pairingCode: String

    init() {
        let stored = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
        pairingCode = PairingSecret.isValid(stored) ? stored : PairingSecret.generate()
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")

        server.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        server.start(pairingCode: pairingCode)
        accessibility.refresh()
        accessibility.promptIfNeeded()
        refreshAddress()
        RemotePacket.runSelfChecks()
    }

    func refreshAddress() {
        localAddress = LocalIPAddress.primaryIPv4() ?? "Unknown"
    }

    func rotatePairingCode() {
        pairingCode = PairingSecret.generate()
        UserDefaults.standard.set(pairingCode, forKey: "pairingCode")
        server.updatePairingCode(pairingCode)
    }

    func testCursor() {
        let result = InputEngine.testNudge(dx: 100)
        let text = "created=\(result.created) posted=\(result.posted) trusted=\(result.trusted) \(Int(result.from.x)),\(Int(result.from.y)) → \(Int(result.to.x)),\(Int(result.to.y))"
        server.recordCursorTest(text, posted: result.posted)
        NSLog("Kamihi cursor test: %@", text)
    }

    func toggle() {
        if server.isRunning {
            server.stop()
        } else {
            refreshAddress()
            server.start(pairingCode: pairingCode)
        }
    }

    private var cancellables = Set<AnyCancellable>()
}
