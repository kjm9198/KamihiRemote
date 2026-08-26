import SwiftUI
import UIKit

struct KamihiAppShell: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var showsConnectionDoctor = false
    @State private var showsGameSessions = ProcessInfo.processInfo.arguments.contains("-KamihiUITestGameSessions")
    @State private var gameSessions: [GameSessionProfile] = GameSessionStore.load()
    @AppStorage("selectedGameSessionID") private var selectedGameSessionID = ""

    var body: some View {
        KamihiPolishedRootView()
            .overlay(alignment: .topTrailing) {
                if session.selectedTab == .controller {
                    Button {
                        session.sendController(.neutral)
                        gameSessions = GameSessionStore.load()
                        showsGameSessions = true
                        Haptics.touchTap()
                    } label: {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(selectedGameSessionID.isEmpty ? .white : .cyan)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .padding(.trailing, 12)
                    .padding(.top, 58)
                    .accessibilityLabel("Game Sessions")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !session.isConnected || session.preferences.showDeveloperDiagnostics {
                    Button {
                        showsConnectionDoctor = true
                        Haptics.touchTap()
                    } label: {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(session.isConnected ? .cyan : .orange)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .padding(.trailing, 12)
                    .padding(.bottom, 68)
                    .accessibilityLabel("Connection Doctor")
                }
            }
            .sheet(isPresented: $showsGameSessions) {
                GameSessionManagerSheet(
                    profiles: $gameSessions,
                    selectedProfileID: $selectedGameSessionID
                )
                .environmentObject(session)
            }
            .sheet(isPresented: $showsConnectionDoctor) {
                NavigationStack {
                    ConnectionDoctorView()
                        .environmentObject(session)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsConnectionDoctor = false }
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
    }
}

struct ConnectionDoctorView: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var copied = false

    private var heartbeatHealthy: Bool {
        session.telemetry.lastHeartbeatAge == 0 || session.telemetry.lastHeartbeatAge < 2.0
    }

    private var latencyHealthy: Bool {
        session.telemetry.rttMilliseconds == 0 || session.telemetry.rttMilliseconds <= 80
    }

    private var gamingReady: Bool {
        session.isConnected
            && session.telemetry.tcpReady
            && session.telemetry.udpConfigured
            && latencyHealthy
            && heartbeatHealthy
    }

    private var vibeReady: Bool {
        session.isConnected && session.telemetry.tcpReady
    }

    var body: some View {
        Form {
            Section("Overall") {
                readinessRow(
                    title: "Vibe coding",
                    detail: vibeReady ? "Reliable command channel ready" : "Needs a live TCP connection",
                    ready: vibeReady,
                    symbol: "sparkles"
                )
                readinessRow(
                    title: "Gaming",
                    detail: gamingReady ? "Realtime path ready" : gamingReadinessReason,
                    ready: gamingReady,
                    symbol: "gamecontroller.fill"
                )
            }

            Section("Connection") {
                statusRow("Session", value: session.connectionState.rawValue.capitalized, ok: session.isConnected)
                statusRow("TCP commands", value: session.telemetry.tcpReady ? "Ready" : "Not ready", ok: session.telemetry.tcpReady)
                statusRow("UDP realtime", value: session.telemetry.udpConfigured ? "Ready" : "Not ready", ok: session.telemetry.udpConfigured)
                statusRow("Transport", value: session.telemetry.transport.isEmpty ? "—" : session.telemetry.transport, ok: session.isConnected)
                statusRow("RTT", value: rttText, ok: latencyHealthy && session.isConnected)
                statusRow("Heartbeat", value: heartbeatText, ok: heartbeatHealthy && session.isConnected)
                LabeledContent("Realtime packets", value: "\(session.telemetry.realtimePacketsPerSecond)/s")
                LabeledContent("Reconnects", value: "\(session.telemetry.reconnects)")
                LabeledContent("Protocol", value: "v\(RemoteConstants.protocolVersionString)")
            }

            Section("Mac Context") {
                LabeledContent("Host", value: session.hostName.isEmpty ? "—" : session.hostName)
                LabeledContent("Active app", value: session.activeAppName.isEmpty ? "—" : session.activeAppName)
                LabeledContent("Focused text", value: focusedTextSummary)

                Button {
                    session.send(.requestActiveApp)
                    session.requestFocusedText()
                    session.send(.requestAppList)
                    Haptics.touchTap()
                } label: {
                    Label("Refresh Mac Context", systemImage: "arrow.clockwise")
                }
                .disabled(!session.isConnected)
            }

            Section("Recovery") {
                Button {
                    session.disconnect(reason: "Reconnecting…")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        session.applySettingsAndConnect()
                    }
                    Haptics.gesture()
                } label: {
                    Label("Reconnect Now", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    session.send(.releaseAll)
                    session.sendController(.neutral)
                    session.flashAction("Released all remote inputs", success: true)
                } label: {
                    Label("Release Stuck Inputs", systemImage: "hand.raised.fill")
                }
                .disabled(!session.isConnected)
            }

            Section("Share Diagnostics") {
                Button {
                    UIPasteboard.general.string = diagnosticReport
                    copied = true
                    Haptics.touchTap()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy Diagnostic Report", systemImage: copied ? "checkmark" : "doc.on.doc")
                }

                Text("The report excludes your pairing code and cryptographic material.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Connection Doctor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var gamingReadinessReason: String {
        if !session.isConnected { return "Connect to the Mac first" }
        if !session.telemetry.tcpReady { return "TCP control channel is unavailable" }
        if !session.telemetry.udpConfigured { return "UDP realtime path is unavailable" }
        if !heartbeatHealthy { return "Heartbeat is stale" }
        if !latencyHealthy { return "Latency is high" }
        return "Checking realtime path"
    }

    private var rttText: String {
        session.telemetry.rttMilliseconds == 0 ? "—" : "\(session.telemetry.rttMilliseconds) ms"
    }

    private var heartbeatText: String {
        guard session.telemetry.lastHeartbeatAge > 0 else { return "—" }
        return String(format: "%.1f s ago", session.telemetry.lastHeartbeatAge)
    }

    private var focusedTextSummary: String {
        switch session.focusedTextStatus {
        case .value:
            return session.focusedTextValue.isEmpty ? "Empty" : "Available"
        case .secure:
            return "Secure field"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var diagnosticReport: String {
        [
            "KamihiRemote Connection Doctor",
            "Protocol: v\(RemoteConstants.protocolVersionString)",
            "State: \(session.connectionState.rawValue)",
            "Host: \(session.hostName.isEmpty ? "unknown" : session.hostName)",
            "Active app: \(session.activeAppName.isEmpty ? "unknown" : session.activeAppName)",
            "Transport: \(session.telemetry.transport.isEmpty ? "unknown" : session.telemetry.transport)",
            "TCP ready: \(session.telemetry.tcpReady)",
            "UDP configured: \(session.telemetry.udpConfigured)",
            "RTT ms: \(session.telemetry.rttMilliseconds)",
            "Heartbeat age s: \(String(format: "%.2f", session.telemetry.lastHeartbeatAge))",
            "Realtime packets/s: \(session.telemetry.realtimePacketsPerSecond)",
            "Reconnects: \(session.telemetry.reconnects)",
            "Vibe ready: \(vibeReady)",
            "Gaming ready: \(gamingReady)"
        ].joined(separator: "\n")
    }

    @ViewBuilder
    private func readinessRow(title: String, detail: String, ready: Bool, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(ready ? .green : .orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ready ? .green : .orange)
        }
    }

    private func statusRow(_ title: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
