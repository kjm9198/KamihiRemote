import Foundation
import LocalAuthentication

@MainActor
final class DesktopPrivacyAuthenticator: ObservableObject {
    static let shared = DesktopPrivacyAuthenticator()

    @Published private(set) var isAuthenticating = false
    @Published private(set) var lastError: String?

    private init() {}

    func lock() {
        DesktopFeatureState.shared.privacyMode = true
        lastError = nil
    }

    func unlock() async -> Bool {
        guard DesktopFeatureState.shared.privacyMode else { return true }
        guard !isAuthenticating else { return false }

        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Keep Locked"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Device authentication is unavailable."
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Kamihi Desktop on the connected display."
            )
            if success { DesktopFeatureState.shared.privacyMode = false }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
