import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Connect") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            session.showsQuickConnect = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pair with 6-Digit PIN")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text("Enter code from Mac menu bar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    TextField("Pairing PIN", text: $session.pairingCode)
                        .keyboardType(.numberPad)
                        .font(.body.monospacedDigit())
                        .onChange(of: session.pairingCode) { _, newValue in
                            if newValue.count == 6 {
                                session.pairWithCode(newValue)
                            }
                        }

                    if !session.pairingCode.isEmpty {
                        Button("Connect with Code") {
                            session.pairWithCode(session.pairingCode)
                            dismiss()
                        }
                        .bold()
                    }
                }

                Section("Discovered & Paired Hosts") {
                    if session.browser.hosts.isEmpty && PairedHostStore.load().isEmpty {
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
                    Picker("Profile", selection: Binding(
                        get: { session.preferences.controllerMapping.profile },
                        set: { newProfile in
                            session.preferences.controllerProfile = newProfile
                            session.preferences.controllerMapping = ControllerMapping.defaultFor(profile: newProfile)
                            session.syncControllerConfig()
                            session.preferences.save()
                        }
                    )) {
                        ForEach(ControllerProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }

                    NavigationLink("Customize Controller Buttons & Sticks") {
                        ControllerCustomizerView().environmentObject(session)
                    }

                    Picker("Layout", selection: $session.preferences.controllerLayout) {
                        ForEach(ControllerLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
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
                    LabeledContent("App Version", value: "0.5.1 (Build 13)")
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

struct ControllerCustomizerView: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var editingButton: IdentifiableButtonName?

    var body: some View {
        Form {
            Section("Active Profile") {
                Picker("Profile", selection: Binding(
                    get: { session.preferences.controllerMapping.profile },
                    set: { newProfile in
                        session.preferences.controllerProfile = newProfile
                        session.preferences.controllerMapping = ControllerMapping.defaultFor(profile: newProfile)
                        session.syncControllerConfig()
                        session.preferences.save()
                    }
                )) {
                    ForEach(ControllerProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            }

            Section("Face Buttons") {
                buttonRow("A Button", action: session.preferences.controllerMapping.a) {
                    editingButton = IdentifiableButtonName(name: "A Button", keyPath: \.a)
                }
                buttonRow("B Button", action: session.preferences.controllerMapping.b) {
                    editingButton = IdentifiableButtonName(name: "B Button", keyPath: \.b)
                }
                buttonRow("X Button", action: session.preferences.controllerMapping.x) {
                    editingButton = IdentifiableButtonName(name: "X Button", keyPath: \.x)
                }
                buttonRow("Y Button", action: session.preferences.controllerMapping.y) {
                    editingButton = IdentifiableButtonName(name: "Y Button", keyPath: \.y)
                }
            }

            Section("D-Pad") {
                buttonRow("D-Pad Up", action: session.preferences.controllerMapping.dpadUp) {
                    editingButton = IdentifiableButtonName(name: "D-Pad Up", keyPath: \.dpadUp)
                }
                buttonRow("D-Pad Down", action: session.preferences.controllerMapping.dpadDown) {
                    editingButton = IdentifiableButtonName(name: "D-Pad Down", keyPath: \.dpadDown)
                }
                buttonRow("D-Pad Left", action: session.preferences.controllerMapping.dpadLeft) {
                    editingButton = IdentifiableButtonName(name: "D-Pad Left", keyPath: \.dpadLeft)
                }
                buttonRow("D-Pad Right", action: session.preferences.controllerMapping.dpadRight) {
                    editingButton = IdentifiableButtonName(name: "D-Pad Right", keyPath: \.dpadRight)
                }
            }

            Section("Bumpers & Triggers") {
                buttonRow("L1 (Left Bumper)", action: session.preferences.controllerMapping.l1) {
                    editingButton = IdentifiableButtonName(name: "L1 (Left Bumper)", keyPath: \.l1)
                }
                buttonRow("R1 (Right Bumper)", action: session.preferences.controllerMapping.r1) {
                    editingButton = IdentifiableButtonName(name: "R1 (Right Bumper)", keyPath: \.r1)
                }
                buttonRow("L2 (Left Trigger)", action: session.preferences.controllerMapping.l2) {
                    editingButton = IdentifiableButtonName(name: "L2 (Left Trigger)", keyPath: \.l2)
                }
                buttonRow("R2 (Right Trigger)", action: session.preferences.controllerMapping.r2) {
                    editingButton = IdentifiableButtonName(name: "R2 (Right Trigger)", keyPath: \.r2)
                }
            }

            Section("Navigation & Sticks") {
                buttonRow("Start", action: session.preferences.controllerMapping.start) {
                    editingButton = IdentifiableButtonName(name: "Start", keyPath: \.start)
                }
                buttonRow("Menu", action: session.preferences.controllerMapping.menu) {
                    editingButton = IdentifiableButtonName(name: "Menu", keyPath: \.menu)
                }
                buttonRow("View", action: session.preferences.controllerMapping.view) {
                    editingButton = IdentifiableButtonName(name: "View", keyPath: \.view)
                }
                Picker("Left Stick", selection: Binding(
                    get: { session.preferences.controllerMapping.leftStick },
                    set: { newStick in
                        session.preferences.controllerMapping.leftStick = newStick
                        session.preferences.controllerMapping.profile = .custom
                        session.syncControllerConfig()
                        session.preferences.save()
                    }
                )) {
                    ForEach(StickAction.allCases) { stick in
                        Text(stick.title).tag(stick)
                    }
                }
                Picker("Right Stick", selection: Binding(
                    get: { session.preferences.controllerMapping.rightStick },
                    set: { newStick in
                        session.preferences.controllerMapping.rightStick = newStick
                        session.preferences.controllerMapping.profile = .custom
                        session.syncControllerConfig()
                        session.preferences.save()
                    }
                )) {
                    ForEach(StickAction.allCases) { stick in
                        Text(stick.title).tag(stick)
                    }
                }
            }
        }
        .navigationTitle("Customize Controller")
        .sheet(item: $editingButton) { item in
            ActionPickerSheet(title: item.name) { newAction in
                session.preferences.controllerMapping[keyPath: item.keyPath] = newAction
                session.preferences.controllerMapping.profile = .custom
                session.syncControllerConfig()
                session.preferences.save()
            }
        }
    }

    private func buttonRow(_ title: String, action: ControllerAction, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(action.title)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct IdentifiableButtonName: Identifiable {
    var id: String { name }
    let name: String
    let keyPath: WritableKeyPath<ControllerMapping, ControllerAction>
}

struct ActionPickerSheet: View {
    let title: String
    let onSelect: (ControllerAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Common Keys") {
                    actionButton("Space (Jump / Space)", .key(code: 49, title: "Space"))
                    actionButton("Return (Enter)", .key(code: 36, title: "Return"))
                    actionButton("Escape", .key(code: 53, title: "Escape"))
                    actionButton("Tab", .key(code: 48, title: "Tab"))
                    actionButton("Shift", .key(code: 56, title: "Shift"))
                    actionButton("Delete / Backspace", .key(code: 51, title: "Delete (⌫)"))
                    actionButton("Up Arrow", .key(code: 126, title: "Up Arrow"))
                    actionButton("Down Arrow", .key(code: 125, title: "Down Arrow"))
                    actionButton("Left Arrow", .key(code: 123, title: "Left Arrow"))
                    actionButton("Right Arrow", .key(code: 124, title: "Right Arrow"))
                }

                Section("Shortcuts") {
                    actionButton("Copy (⌘C)", .shortcut(spec: "cmd+c", title: "Copy (⌘C)"))
                    actionButton("Paste (⌘V)", .shortcut(spec: "cmd+v", title: "Paste (⌘V)"))
                    actionButton("Undo (⌘Z)", .shortcut(spec: "cmd+z", title: "Undo (⌘Z)"))
                    actionButton("Redo (⌘⇧Z)", .shortcut(spec: "cmd+shift+z", title: "Redo (⌘⇧Z)"))
                    actionButton("Save (⌘S)", .shortcut(spec: "cmd+s", title: "Save (⌘S)"))
                    actionButton("Select All (⌘A)", .shortcut(spec: "cmd+a", title: "Select All (⌘A)"))
                    actionButton("App Switcher (⌘Tab)", .shortcut(spec: "cmd+tab", title: "App Switcher (⌘Tab)"))
                    actionButton("Find (⌘F)", .shortcut(spec: "cmd+f", title: "Find (⌘F)"))
                }

                Section("Mouse & Trackpad") {
                    actionButton("Left Click", .click)
                    actionButton("Right Click", .rightClick)
                }

                Section("macOS Spaces & System") {
                    actionButton("Mission Control", .system(.missionControl))
                    actionButton("App Exposé", .system(.appExpose))
                    actionButton("Show Desktop", .system(.showDesktop))
                    actionButton("Previous Desktop (←)", .system(.previousDesktop))
                    actionButton("Next Desktop (→)", .system(.nextDesktop))
                }

                Section("Media Controls") {
                    actionButton("Play / Pause", .media(.playPause))
                    actionButton("Volume Up", .media(.volumeUp))
                    actionButton("Volume Down", .media(.volumeDown))
                    actionButton("Next Track", .media(.next))
                    actionButton("Previous Track", .media(.previous))
                }

                Section("Presentation") {
                    actionButton("Next Slide", .presentation(.next))
                    actionButton("Previous Slide", .presentation(.previous))
                    actionButton("Start Slideshow", .presentation(.start))
                    actionButton("Exit Slideshow", .presentation(.end))
                }

                Section("Other") {
                    actionButton("None (Disabled)", .none)
                }
            }
            .navigationTitle("Assign \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func actionButton(_ label: String, _ action: ControllerAction) -> some View {
        Button(label) {
            onSelect(action)
            dismiss()
        }
        .foregroundStyle(.primary)
    }
}
