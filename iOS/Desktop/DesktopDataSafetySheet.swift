import SwiftUI

/// Explains Apple's sandbox architecture, local-only storage, and privacy guarantees for Kamihi Desktop.
struct DesktopDataSafetySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                            .padding(.top, 8)

                        Text("Your Data Stays On Your iPhone")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text("Kamihi Desktop is engineered from the ground up to respect iOS security boundaries and keep your private information safe.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Apple iOS App Sandbox") {
                    SafetyRow(
                        icon: "shippingbox.fill",
                        color: .blue,
                        title: "Strict Sandbox Isolation",
                        detail: "iOS isolates Kamihi Desktop from Safari and other apps. Kamihi cannot access Safari's internal databases, and other apps cannot access Kamihi's private files."
                    )
                    SafetyRow(
                        icon: "doc.badge.arrow.up",
                        color: .purple,
                        title: "Explicit User Document Selection",
                        detail: "When importing Safari bookmarks or opening documents, access is granted only to the specific file you pick through Apple's native document picker."
                    )
                }

                Section("Local-Only Storage") {
                    SafetyRow(
                        icon: "internaldrive.fill",
                        color: .teal,
                        title: "Zero Cloud Telemetry",
                        detail: "All documents, sheets, notes, clipboard history, and browser data are stored strictly on-device in Application Support. Nothing is uploaded to remote servers."
                    )
                    SafetyRow(
                        icon: "checkmark.shield.fill",
                        color: .green,
                        title: "Privacy-Filtered URLs",
                        detail: "All saved bookmarks and browser URLs automatically strip authentication tokens, tracking query parameters, and sensitive session fragments before saving."
                    )
                }

                Section("Passwords, Passkeys & Payments") {
                    SafetyRow(
                        icon: "faceid",
                        color: .indigo,
                        title: "Native Apple AutoFill & Face ID",
                        detail: "Web logins use Apple's native WebKit credential provider. Your passwords and passkeys remain securely stored in your iOS iCloud Keychain and are authenticated via Face ID. Kamihi never sees, logs, or stores your passwords."
                    )
                }
            }
            .navigationTitle("Privacy & Safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SafetyRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
