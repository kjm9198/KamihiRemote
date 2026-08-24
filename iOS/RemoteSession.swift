import Combine
import Foundation
import SwiftUI

@MainActor
final class RemoteSession: ObservableObject {
    let udp = UDPClient()
    let engine: TouchInputEngine

    @AppStorage("hostAddress") var hostAddress = ""
    @AppStorage("hostPort") var hostPort = Int(RemoteConstants.defaultPort)
    @AppStorage("pairingCode") var pairingCode = ""
    @AppStorage("sensitivity") var sensitivity = 1.8

    @Published var showsSettings = false
    @Published var selectedTab: RemoteTab = .trackpad

    init() {
        engine = TouchInputEngine(udp: udp)
        engine.sensitivity = sensitivity
        udp.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func connectIfPossible() {
        engine.sensitivity = sensitivity
        let host = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, PairingSecret.isValid(code) else { return }
        udp.connect(host: host, port: UInt16(clamping: hostPort), pairingCode: code)
    }

    func applySettingsAndConnect() {
        engine.sensitivity = sensitivity
        connectIfPossible()
    }

    private var cancellables = Set<AnyCancellable>()
}

enum RemoteTab: String, CaseIterable, Identifiable {
    case trackpad
    case slides
    case settings

    var id: String { rawValue }
}
