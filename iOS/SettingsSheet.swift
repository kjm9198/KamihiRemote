import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Nearby Macs") {
                    if session.browser.hosts.isEmpty {
                        Text("Searching on this Wi-Fi…")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.browser.hosts) { host in
                        Button {
                            session.pairingCode = session.pairingCode
                            session.connect(to: HostIdentity(
                                hostID: host.hostID,
                                displayName: host.name,
                                pairingSecret: session.pairingCode,
                                lastAddress: host.address,
                                lastPort: host.port,
                                lastTCPPort: host.tcpPort,
                                lastConnected: nil
                            ))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(host.name).foregroundStyle(.primary)
                                Text(host.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Paired") {
                    ForEach(PairedHostStore.load()) { host in
                        HStack {
                            Button(host.displayName) {
                                session.connect(to: host)
                                dismiss()
                            }
                            Spacer()
                            Button("Forget", role: .destructive) {
                                session.forget(host.hostID)
                            }
                        }
                    }
                }

                Section("Manual IP") {
                    TextField("IP address", text: $session.manualAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Pairing code", text: $session.pairingCode)
                        .keyboardType(.numberPad)
                    Stepper(value: $session.manualPort, in: 1024...65535) {
                        HStack {
                            Text("UDP port")
                            Spacer()
                            Text("\(session.manualPort)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    Button("Connect") {
                        session.applySettingsAndConnect()
                        dismiss()
                    }
                    .disabled(session.manualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Trackpad") {
                    Picker("Feel", selection: $session.preferences.pointerPreset) {
                        ForEach(PointerPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    Toggle("Custom sensitivity", isOn: $session.preferences.useCustomSensitivity)
                    if session.preferences.useCustomSensitivity {
                        Slider(value: $session.preferences.customSensitivity, in: 0.6...4.0, step: 0.1)
                    }
                    Toggle("Smoothing", isOn: $session.preferences.smoothingEnabled)
                    Toggle("Natural scrolling", isOn: $session.preferences.naturalScrolling)
                    Toggle("Tap to click", isOn: $session.preferences.tapToClick)
                    Toggle("Two-finger secondary click", isOn: $session.preferences.twoFingerSecondaryClick)
                }

                Section("Gestures") {
                    gesturePicker("3-finger left", $session.preferences.bindings.threeFingerLeft)
                    gesturePicker("3-finger right", $session.preferences.bindings.threeFingerRight)
                    gesturePicker("3-finger up", $session.preferences.bindings.threeFingerUp)
                    gesturePicker("3-finger down", $session.preferences.bindings.threeFingerDown)
                    gesturePicker("4-finger left", $session.preferences.bindings.fourFingerLeft)
                    gesturePicker("4-finger right", $session.preferences.bindings.fourFingerRight)
                    gesturePicker("4-finger up", $session.preferences.bindings.fourFingerUp)
                    gesturePicker("4-finger down", $session.preferences.bindings.fourFingerDown)
                }

                Section("Haptics") {
                    Picker("Haptics", selection: $session.preferences.hapticLevel) {
                        ForEach(HapticLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Orientation") {
                    Picker("Orientation", selection: $session.preferences.orientation) {
                        ForEach(OrientationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section("Developer") {
                    Toggle("Developer diagnostics", isOn: $session.preferences.showDeveloperDiagnostics)
                    LabeledContent("Protocol", value: "v\(RemoteConstants.protocolVersionString)")
                    LabeledContent("Transport", value: session.telemetry.transport)
                    LabeledContent("RTT", value: "\(session.telemetry.rttMilliseconds) ms")
                    LabeledContent("Reconnects", value: "\(session.telemetry.reconnects)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear { session.preferences.save() }
        }
    }

    private func gesturePicker(_ title: String, _ value: Binding<SystemAction>) -> some View {
        Picker(title, selection: value) {
            ForEach(SystemAction.allCases, id: \.self) { action in
                Text(action.title).tag(action)
            }
        }
    }
}
