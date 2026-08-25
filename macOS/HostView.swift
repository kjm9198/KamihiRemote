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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Kamihi Remote Host")
                        .font(.largeTitle.weight(.semibold))
                    Text("v0.5.0")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Text(host.server.clientConnected ? "Phone connected" : "Waiting for your iPhone or iPad on this Wi-Fi.")
                    .foregroundStyle(.secondary)

                pairingCard
                if let pending = host.pendingPairing {
                    pendingCard(pending)
                }
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
            Text("This code expires in two minutes and is only for first pairing. Approve the iPhone on this Mac.")
                .foregroundStyle(.secondary)
            if let image = qrImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 148, height: 148)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pendingCard(_ pending: PendingPairing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW IPHONE WANTS TO CONNECT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(pending.deviceName).font(.title2.weight(.semibold))
            HStack {
                Button("Approve") { host.approvePending() }
                    .keyboardShortcut(.defaultAction)
                Button("Deny", role: .destructive) { host.denyPending() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var qrImage: NSImage? {
        QRCode.image(from: host.qrPayload)
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

                Divider().padding(.vertical, 8)

                Text("Local Injection Tests (Bypasses Phone Network)").font(.title2.weight(.semibold))
                Text("Clicking these tests CGEvent injection and SpaceChangeVerifier notification on this Mac.").foregroundStyle(.secondary).font(.callout)

                HStack(spacing: 10) {
                    Button("TEST DESKTOP ←") { host.testSystemAction(.previousDesktop) }
                        .disabled(host.isTestingAction)
                    Button("TEST DESKTOP →") { host.testSystemAction(.nextDesktop) }
                        .disabled(host.isTestingAction)
                    Button("TEST MISSION CONTROL") { host.testSystemAction(.missionControl) }
                        .disabled(host.isTestingAction)
                    Button("TEST APP EXPOSÉ") { host.testSystemAction(.appExpose) }
                        .disabled(host.isTestingAction)
                }
                .padding(.vertical, 4)

                if host.lastTestResultText.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Test Output:")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(host.lastTestResultText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(host.lastTestResultText.contains("PASS") ? Color.green : (host.lastTestResultText.contains("Testing") ? Color.cyan : Color.red))
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
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
            Section("Trusted Devices") {
                if host.trustedDevices.isEmpty {
                    Text("No phones have been approved yet.").foregroundStyle(.secondary)
                }
                ForEach(host.trustedDevices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.displayName)
                            Text("Last used \(device.lastUsed.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) { host.revokeDevice(device.deviceID) }
                    }
                }
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
