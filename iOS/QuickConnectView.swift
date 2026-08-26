import SwiftUI

/// Fast, frictionless 6-digit PIN & Direct IP connection interface.
struct QuickConnectView: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput: String = ""
    @State private var manualIPInput: String = ""
    @State private var manualPortInput: String = "\(RemoteConstants.defaultTCPPort)"
    @State private var showManualIP = false
    @State private var isConnecting = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(session.isConnected ? Color.green.opacity(0.2) : Color.cyan.opacity(0.15))
                                    .frame(width: 72, height: 72)
                                Image(systemName: session.isConnected ? "checkmark.circle.fill" : "laptopcomputer.and.iphone")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(session.isConnected ? Color.green : Color.cyan)
                            }
                            .padding(.top, 8)

                            Text(session.isConnected ? "Connected to Mac" : "Pair with your Mac")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(session.isConnected
                                 ? "You can now control your Mac with trackpad, voice, and deck."
                                 : "On your Mac, open Kamihi Remote Host and enter the 6-digit pairing code shown there. Same Wi‑Fi required.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        if session.isConnected {
                            // Connected Summary
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.hostName.isEmpty ? "Mac" : session.hostName)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text(session.telemetry.transport)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Button("Disconnect", role: .destructive) {
                                        session.disconnect(reason: "User disconnected")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal, 16)
                        } else {
                            // 6-Digit PIN Entry Section
                            VStack(spacing: 12) {
                                Text("6-DIGIT PAIRING CODE")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.45))

                                // Code input field with clear visual digits
                                HStack(spacing: 8) {
                                    let digits = Array(codeInput.padding(toLength: 6, withPad: "•", startingAt: 0))
                                    ForEach(0..<6, id: \.self) { index in
                                        let char = digits[index]
                                        let isFilled = index < codeInput.count
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(isFilled ? 0.15 : 0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(index == codeInput.count && isCodeFocused ? Color.cyan : Color.white.opacity(0.12), lineWidth: index == codeInput.count && isCodeFocused ? 2 : 1)
                                                )
                                                .frame(width: 46, height: 56)

                                            Text(isFilled ? String(char) : "")
                                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .overlay {
                                    TextField("", text: $codeInput)
                                        .keyboardType(.numberPad)
                                        .textContentType(.oneTimeCode)
                                        .focused($isCodeFocused)
                                        .opacity(0.01)
                                        .onChange(of: codeInput) { _, newValue in
                                            let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                                            codeInput = filtered
                                            if filtered.count == 6 {
                                                triggerPairing(code: filtered)
                                            }
                                        }
                                }
                                .onTapGesture {
                                    isCodeFocused = true
                                }

                                HStack(spacing: 12) {
                                    Button {
                                        if let clip = UIPasteboard.general.string {
                                            let digits = String(clip.filter { $0.isNumber }.prefix(6))
                                            if !digits.isEmpty {
                                                codeInput = digits
                                                if digits.count == 6 {
                                                    triggerPairing(code: digits)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Paste PIN", systemImage: "doc.on.clipboard")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.cyan)

                                    Button {
                                        triggerPairing(code: codeInput)
                                    } label: {
                                        HStack(spacing: 6) {
                                            if isConnecting {
                                                ProgressView()
                                                    .tint(.black)
                                            }
                                            Text("Pair & Connect")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.white)
                                    .foregroundStyle(.black)
                                    .disabled(codeInput.count < 6 || isConnecting)
                                }
                                .padding(.top, 4)
                            }
                            .padding(18)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)

                            // Discovered Macs List
                            if !session.browser.hosts.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("NEARBY MACS (BONJOUR)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .tracking(1.2)
                                        .foregroundStyle(.white.opacity(0.45))
                                        .padding(.horizontal, 4)

                                    ForEach(session.browser.hosts) { host in
                                        Button {
                                            session.connect(to: host)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "desktopcomputer")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(.cyan)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(host.name)
                                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                                        .foregroundStyle(.white)
                                                    Text(host.isResolved ? host.address : "Discovered")
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                }
                                                Spacer()
                                                Text("Connect")
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color.cyan.opacity(0.2), in: Capsule())
                                                    .foregroundStyle(.cyan)
                                            }
                                            .padding(14)
                                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            // Manual IP Direct Connect Toggle
                            VStack(spacing: 10) {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        showManualIP.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: showManualIP ? "chevron.down" : "network")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(showManualIP ? "Hide Manual IP" : "Connect via Direct IP Address")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        Spacer()
                                    }
                                    .foregroundStyle(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 4)

                                if showManualIP {
                                    VStack(spacing: 10) {
                                        HStack(spacing: 8) {
                                            TextField("Mac IP Address (e.g. 192.168.1.43)", text: $manualIPInput)
                                                .keyboardType(.decimalPad)
                                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                .padding(12)
                                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                                .foregroundStyle(.white)

                                            TextField("Port", text: $manualPortInput)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                .frame(width: 80)
                                                .padding(12)
                                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                                .foregroundStyle(.white)
                                        }

                                        Button {
                                            let port = UInt16(manualPortInput) ?? RemoteConstants.defaultTCPPort
                                            session.connectDirect(ip: manualIPInput, port: port, code: codeInput)
                                        } label: {
                                            Text("Connect to IP")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 38)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.cyan)
                                        .disabled(manualIPInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Live Status Footer
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(session.isConnected ? Color.green : (session.connectionState == .connecting ? Color.yellow : Color.orange))
                                    .frame(width: 8, height: 8)
                                Text(session.statusText)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                            }

                            Text("Kamihi Remote v0.5.1 (Build 13)")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            codeInput = session.pairingCode
            // Prefer last known Mac address — never the phone's own LocalIPAddress.
            let hint = session.preferredMacAddressHint()
            manualIPInput = hint
            showManualIP = hint.isEmpty && session.browser.hosts.isEmpty
            if codeInput.isEmpty {
                isCodeFocused = true
            }
        }
        .onChange(of: session.isConnected) { _, connected in
            if connected {
                Haptics.connect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }

    private func triggerPairing(code: String) {
        isConnecting = true
        let ip = manualIPInput.trimmingCharacters(in: .whitespacesAndNewlines)
        session.pairWithCode(code, manualIP: NetworkEndpoint.looksLikeNumericHost(ip) ? ip : nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isConnecting = false
        }
    }
}
