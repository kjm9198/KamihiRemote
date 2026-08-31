import SwiftUI
import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let sharedHost = HostSession()
    var host: HostSession { Self.sharedHost }

    override init() {
        super.init()
        _ = Self.sharedHost
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setbuf(stdout, nil)
        setbuf(stderr, nil)
    }
}

@main
struct KamihiRemoteHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        _ = AppDelegate.sharedHost
    }

    var body: some Scene {
        WindowGroup("Kamihi Remote Host") {
            HostView()
                .environmentObject(appDelegate.host)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 840, height: 620)

        MenuBarExtra("Kamihi Remote", systemImage: appDelegate.host.server.clientConnected ? "dot.radiowaves.left.and.right" : "laptopcomputer") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    appDelegate.host.server.clientConnected ? (appDelegate.host.connectedDeviceName.isEmpty ? "Phone connected" : appDelegate.host.connectedDeviceName) : "Waiting for phone",
                    systemImage: appDelegate.host.server.clientConnected ? "checkmark.circle.fill" : "circle"
                )
                Text("Pairing \(appDelegate.host.pairingCode)").monospacedDigit()
                Text(appDelegate.host.localAddress).foregroundStyle(.secondary)
                Divider()
                Toggle("Launch at login", isOn: Binding(
                    get: { appDelegate.host.launchAtLogin },
                    set: { appDelegate.host.setLaunchAtLogin($0) }
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
                Button("Test Cursor") { appDelegate.host.testCursor() }
                Button(appDelegate.host.server.isRunning ? "Stop Host" : "Start Host") { appDelegate.host.toggle() }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding(8)
        }
        .menuBarExtraStyle(.window)

        Settings {
            HostPreferencesView()
                .environmentObject(appDelegate.host)
                .frame(width: 420)
        }
    }
}
