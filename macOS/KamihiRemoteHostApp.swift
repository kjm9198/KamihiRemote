import SwiftUI
import AppKit
import ServiceManagement

@main
struct KamihiRemoteHostApp: App {
    @StateObject private var host = HostSession()

    var body: some Scene {
        WindowGroup("Kamihi Remote Host") {
            HostView()
                .environmentObject(host)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 840, height: 620)

        MenuBarExtra("Kamihi Remote", systemImage: host.server.clientConnected ? "dot.radiowaves.left.and.right" : "laptopcomputer") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    host.server.clientConnected ? (host.connectedDeviceName.isEmpty ? "Phone connected" : host.connectedDeviceName) : "Waiting for phone",
                    systemImage: host.server.clientConnected ? "checkmark.circle.fill" : "circle"
                )
                Text("Pairing \(host.pairingCode)").monospacedDigit()
                Text(host.localAddress).foregroundStyle(.secondary)
                Divider()
                Toggle("Launch at login", isOn: Binding(
                    get: { host.launchAtLogin },
                    set: { host.setLaunchAtLogin($0) }
                ))
                Button("Open Kamihi Remote") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.isVisible == false || window.title.contains("Kamihi") {
                        window.makeKeyAndOrderFront(nil)
                    }
                    if NSApp.windows.isEmpty == false {
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                }
                Button("Test Cursor") { host.testCursor() }
                Button(host.server.isRunning ? "Stop Host" : "Start Host") { host.toggle() }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding(8)
        }
        .menuBarExtraStyle(.window)

        Settings {
            HostPreferencesView()
                .environmentObject(host)
                .frame(width: 420)
        }
    }
}
