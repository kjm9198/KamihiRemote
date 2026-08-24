import SwiftUI
import AppKit
import ServiceManagement

struct HostView: View {
    @EnvironmentObject private var host: HostSession
    @State private var section: Section = .overview

    private enum Section: String, CaseIterable, Identifiable, Hashable {
        case overview, preferences, diagnostics
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Status"
            case .preferences: return "Preferences"
            case .diagnostics: return "Diagnostics"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: Binding(
                get: { section },
                set: { if let value = $0 { section = value } }
            )) { item in
                Text(item.title).tag(item)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            switch section {
            case .overview:
                overview
            case .preferences:
                HostPreferencesView()
            case .diagnostics:
                diagnostics
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            host.accessibility.refresh()
            host.refreshAddress()
            NSApp.setActivationPolicy(.regular)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            host.accessibility.refresh()
            host.refreshAddress()
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Kamihi Remote Host")
                    .font(.largeTitle.weight(.semibold))
                Text(host.server.clientConnected ? "Phone connected" : "Waiting for your iPhone or iPad on this Wi-Fi.")
                    .foregroundStyle(.secondary)

                pairingCard
                statusRow(title: host.server.isRunning ? "Host running" : "Host stopped", ok: host.server.isRunning)
                statusRow(title: "Accessibility", ok: host.accessibility.isTrusted)
                labeled("This Mac", value: Host.current().localizedName ?? "Mac")
                labeled("Address", value: host.localAddress) { copy(host.localAddress) }
                labeled("TCP / UDP", value: "\(RemoteConstants.defaultTCPPort) / \(host.server.port)")
                labeled("Device", value: host.server.clientConnected ? (host.connectedDeviceName.isEmpty ? host.server.clientLabel : host.connectedDeviceName) : "Waiting")

                if let error = host.server.lastError {
                    Text(error).foregroundStyle(.red)
                }

                HStack {
                    if host.accessibility.isTrusted == false {
                        Button("Open Accessibility Settings") { host.accessibility.openSettings() }
                    }
                    Spacer()
                    Button("Test Cursor") { host.testCursor() }
                    Button(host.server.isRunning ? "Stop Host" : "Start Host") { host.toggle() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PAIRING CODE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(host.pairingCode)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") { copy(host.pairingCode) }
                    .buttonStyle(.borderless)
                Button("New Code") { host.rotatePairingCode() }
                    .buttonStyle(.borderless)
            }
            Text("Enter this code once on the phone, then Kamihi can reconnect automatically on this Wi-Fi.")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var diagnostics: some View {
        let stats = host.server.stats
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pipeline").font(.title2.weight(.semibold))
                diag("RX packets", "\(stats.packetsReceived)")
                diag("RX / sec", "\(stats.packetsPerSecond)")
                diag("MOVE packets", "\(stats.movePackets)")
                diag("MOVE / sec", "\(stats.movePacketsPerSecond)")
                diag("Accepted", "\(stats.accepted)")
                diag("Rejected", "\(stats.rejected)")
                diag("Last reject", stats.lastRejection)
                diag("Last command", stats.lastCommand)
                diag("Last dx", stats.lastDx)
                diag("Last dy", stats.lastDy)
                diag("CGEvents posted", "\(stats.cgEventsPosted)")
                diag("Last packet", stats.lastPacketAt)
                diag("Client IP", stats.clientIP)
                diag("Cursor test", stats.lastTestResult)
                diag("Last raw packet", stats.lastRawPacket)
                diag("Parsed", stats.lastParsed)
            }
            .font(.body.monospaced())
            .padding(28)
        }
    }

    private func statusRow(title: String, ok: Bool) -> some View {
        HStack {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(title).font(.headline)
            Spacer()
            Text(ok ? "Ready" : "Needed").foregroundStyle(.secondary)
        }
    }

    private func labeled(_ title: String, value: String, copy copyAction: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospaced())
            if let copyAction {
                Button("Copy", action: copyAction).buttonStyle(.borderless)
            }
        }
    }

    private func diag(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct HostPreferencesView: View {
    @EnvironmentObject private var host: HostSession

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { host.launchAtLogin },
                    set: { host.setLaunchAtLogin($0) }
                ))
                Toggle("Host running", isOn: Binding(
                    get: { host.server.isRunning },
                    set: { _ in host.toggle() }
                ))
            }
            Section("Pairing") {
                LabeledContent("Code", value: host.pairingCode)
                Button("Rotate pairing code") { host.rotatePairingCode() }
            }
            Section("This Mac") {
                LabeledContent("Address", value: host.localAddress)
                LabeledContent("Accessibility", value: host.accessibility.isTrusted ? "Allowed" : "Needed")
                if host.accessibility.isTrusted == false {
                    Button("Open Accessibility Settings") { host.accessibility.openSettings() }
                }
            }
            Section("About") {
                LabeledContent("Protocol", value: "v\(RemoteConstants.protocolVersionString)")
                Text("Kamihi stays on your local Wi-Fi. Nothing is sent to the cloud.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
