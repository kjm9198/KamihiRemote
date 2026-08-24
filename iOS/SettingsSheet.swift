import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field {
        case host
        case code
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mac") {
                    TextField("IP address", text: $session.hostAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .host)

                    TextField("Pairing code", text: $session.pairingCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .code)

                    Stepper(value: $session.hostPort, in: 1024...65535) {
                        HStack {
                            Text("Port")
                            Spacer()
                            Text("\(session.hostPort)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Cursor") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text(session.sensitivity, format: .number.precision(.fractionLength(1)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $session.sensitivity, in: 0.6...4.0, step: 0.1)
                    }
                }

                Section {
                    Button("Connect") {
                        session.applySettingsAndConnect()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canConnect)
                } footer: {
                    Text("On your Mac, run Kamihi Remote Host. Copy the IP address and 6-digit pairing code from that window. Both devices must be on the same Wi-Fi.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if session.hostAddress.isEmpty {
                    focusedField = .host
                } else if !PairingSecret.isValid(session.pairingCode) {
                    focusedField = .code
                }
            }
        }
    }

    private var canConnect: Bool {
        !session.hostAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && PairingSecret.isValid(session.pairingCode)
    }
}
