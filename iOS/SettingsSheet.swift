import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    if session.browser.hosts.isEmpty {
                        Text("Searching on this Wi-Fi…").foregroundStyle(.secondary)
                    }
                    ForEach(session.browser.hosts) { host in
                        Button {
                            session.connect(to: host)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(host.name)
                                Text(host.isResolved ? host.address : "Nearby").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(PairedHostStore.load()) { host in
                        HStack {
                            Button(host.displayName) {
                                session.connect(to: host)
                                dismiss()
                            }
                            Spacer()
                            Button("Forget", role: .destructive) { session.forget(host.hostID) }
                        }
                    }
                    TextField("Temporary pairing code", text: $session.pairingCode)
                        .keyboardType(.numberPad)
                        .font(.body.monospacedDigit())
                    Toggle("Automatic", isOn: $session.preferences.automaticTransport)
                    Picker("Preferred transport", selection: $session.preferences.preferredTransport) {
                        ForEach(TransportKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    LabeledContent("Active", value: session.telemetry.transport)
                    Text(session.transport.wiredStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    Toggle("Tap to click", isOn: $session.preferences.tapToClick)
                    Toggle("Two-finger secondary click", isOn: $session.preferences.twoFingerSecondaryClick)
                    Toggle("Pinch to zoom", isOn: $session.preferences.pinchEnabled)
                    Picker("Scroll feel", selection: $session.preferences.scrollFeel) {
                        ForEach(ScrollFeel.allCases) { feel in
                            Text(feel.title).tag(feel)
                        }
                    }
                    Slider(value: $session.preferences.scrollSpeed, in: 0.4...2.4, step: 0.05) {
                        Text("Scroll speed")
                    }
                    Toggle("Natural scrolling", isOn: $session.preferences.naturalScrolling)
                    if session.preferences.scrollFeel == .custom {
                        Slider(value: $session.preferences.scrollMomentum, in: 0.7...0.98, step: 0.01) {
                            Text("Momentum")
                        }
                    }
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
                    TextField("Pinch in", text: $session.preferences.pinchInShortcut)
                    TextField("Pinch out", text: $session.preferences.pinchOutShortcut)
                }

                Section("Deck") {
                    Button("Edit Deck") { session.showsDeckEditor = true }
                    Text("Tap + on Deck, choose Application, then pick a Mac app once.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Controller") {
                    Picker("Layout", selection: $session.preferences.controllerLayout) {
                        ForEach(ControllerLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    Picker("Game mapping", selection: $session.preferences.gameMapping) {
                        ForEach(GameMapping.allCases) { mapping in
                            Text(mapping.title).tag(mapping)
                        }
                    }
                    Slider(value: $session.preferences.stickDeadZone, in: 0.04...0.3, step: 0.01) { Text("Dead zone") }
                    Slider(value: $session.preferences.stickSensitivity, in: 0.5...2.0, step: 0.05) { Text("Stick sensitivity") }
                    Toggle("Haptics", isOn: $session.preferences.controllerHaptics)
                    LabeledContent("Native Gamepad Driver", value: session.transport.nativeGamepadStatus)
                }

                Section("Presentation") {
                    Picker("Profile", selection: $session.preferences.presentationProfile) {
                        ForEach(PresentationProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                    Picker("Pointer style", selection: $session.preferences.presentationPointerStyle) {
                        ForEach(PresentationPointerStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Haptics", selection: $session.preferences.hapticLevel) {
                        ForEach(HapticLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Orientation", selection: $session.preferences.orientation) {
                        ForEach(OrientationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section("Advanced") {
                    Toggle("Developer diagnostics", isOn: $session.preferences.showDeveloperDiagnostics)
                    LabeledContent("Protocol", value: "v\(RemoteConstants.protocolVersionString)")
                    LabeledContent("RTT", value: session.telemetry.rttMilliseconds == 0 ? "—" : "\(session.telemetry.rttMilliseconds) ms")
                    LabeledContent("Reconnects", value: "\(session.telemetry.reconnects)")
                    TextField("Manual IP", text: $session.manualAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear { session.preferences.save() }
            .sheet(isPresented: $session.showsDeckEditor) {
                DeckEditorSheet().environmentObject(session)
            }
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
