import SwiftUI

struct HostView: View {
    @EnvironmentObject private var host: HostSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kamihi Remote Host")
                        .font(.system(size: 26, weight: .semibold))
                    Text("Pipeline diagnostics are on until cursor movement works.")
                        .foregroundStyle(.secondary)
                }

                pairingCard
                statusRow(title: host.server.isRunning ? "Running" : "Stopped", ok: host.server.isRunning)
                labeled("Address", value: host.localAddress) { copy(host.localAddress) }
                labeled("Port", value: "\(host.server.port)")
                labeled("iPhone", value: host.server.clientConnected ? "Connected · \(host.server.clientLabel)" : "Waiting")
                statusRow(title: "Accessibility", ok: host.accessibility.isTrusted)

                diagnostics

                if let error = host.server.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack {
                    if !host.accessibility.isTrusted {
                        Button("Open Accessibility Settings") {
                            host.accessibility.openSettings()
                        }
                    }
                    Spacer()
                    Button("Test Cursor +100px") {
                        host.testCursor()
                    }
                    Button(host.server.isRunning ? "Stop Host" : "Start Host") {
                        host.toggle()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 460, minHeight: 720)
        .onAppear {
            host.accessibility.refresh()
            host.refreshAddress()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            host.accessibility.refresh()
            host.refreshAddress()
        }
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PAIRING CODE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(host.pairingCode)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") { copy(host.pairingCode) }
                    .buttonStyle(.borderless)
                Button("New Code") { host.rotatePairingCode() }
                    .buttonStyle(.borderless)
            }
            Text("Every MOVE packet must include this code. Packets without it are counted as Rejected.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var diagnostics: some View {
        let stats = host.server.stats
        return VStack(alignment: .leading, spacing: 8) {
            Text("PIPELINE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)
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
        .font(.system(.body, design: .monospaced))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func diag(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(4)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusRow(title: String, ok: Bool) -> some View {
        HStack {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.headline)
            Spacer()
            Text(ok ? "✓" : "Needed")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func labeled(_ title: String, value: String, copy copyAction: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            if let copyAction {
                Button("Copy", action: copyAction)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
