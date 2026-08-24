import SwiftUI
import ServiceManagement

@main
struct KamihiRemoteHostApp: App {
    @StateObject private var host = HostSession()

    var body: some Scene {
        MenuBarExtra("Kamihi Remote", systemImage: host.server.clientConnected ? "dot.radiowaves.left.and.right" : "laptopcomputer") {
            VStack(alignment: .leading, spacing: 8) {
                Label(host.server.clientConnected ? (host.connectedDeviceName.isEmpty ? "iPhone connected" : host.connectedDeviceName) : "Waiting for iPhone", systemImage: host.server.clientConnected ? "checkmark.circle.fill" : "circle")
                Text("Pairing \(host.pairingCode)").monospacedDigit()
                Text(host.localAddress).foregroundStyle(.secondary)
                Divider()
                Toggle("Launch at login", isOn: Binding(
                    get: { host.launchAtLogin },
                    set: { host.setLaunchAtLogin($0) }
                ))
                Button("Test Cursor") { host.testCursor() }
                Button(host.server.isRunning ? "Stop Host" : "Start Host") { host.toggle() }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding(8)
        }
        .menuBarExtraStyle(.window)

        Window("Kamihi Remote Host", id: "host") {
            HostView()
                .environmentObject(host)
                .frame(minWidth: 460, minHeight: 720)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 780)
    }
}
