import SwiftUI

@main
struct KamihiRemoteApp: App {
    @StateObject private var router = AppModeRouter()
    @StateObject private var desktop = DesktopSession.shared
    @StateObject private var desktopRecovery = DesktopRecoveryCoordinator.shared
    @State private var deferredSetupThisLaunch = false

    private var setupPreviewStep: DesktopSetupStep? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-KamihiSetupStep"), args.indices.contains(index + 1) {
            return DesktopSetupStep(rawValue: args[index + 1])
        }
        #endif
        return nil
    }

    private var shouldShowSetup: Bool {
        if setupPreviewStep != nil { return !deferredSetupThisLaunch }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-KamihiModeChooser") { return false }
        #endif
        return !DesktopSetupProgress().isComplete && !deferredSetupThisLaunch
    }

    init() {
        #if DEBUG
        let gesturePassed = GestureEngineTests.runSelfChecks()
        let servicesPassed = DesktopServicesTests.runSelfChecks()
        let refactor = DesktopRefactorTests.runSelfChecks()
        NSLog("=== KAMIHI ON-DEVICE RUNTIME SELF-CHECKS ===")
        NSLog("Gesture checks: %@", gesturePassed ? "PASSED ✓" : "FAILED ✗")
        NSLog("Desktop service checks: %@", servicesPassed ? "PASSED ✓" : "FAILED ✗")
        NSLog("Refactor architecture checks: %d/%d passed", refactor.filter { $0.passed }.count, refactor.count)
        var logLines = [
            "=== KAMIHI ON-DEVICE RUNTIME SELF-CHECKS ===",
            "Gesture checks: \(gesturePassed ? "PASSED ✓" : "FAILED ✗")",
            "Desktop service checks: \(servicesPassed ? "PASSED ✓" : "FAILED ✗")",
            "Refactor architecture checks: \(refactor.filter { $0.passed }.count)/\(refactor.count) passed"
        ]
        for r in refactor {
            NSLog("  [%@] %@: %@", r.passed ? "PASS" : "FAIL", r.name, r.message)
            logLines.append("  [\(r.passed ? "PASS" : "FAIL")] \(r.name): \(r.message)")
        }
        NSLog("============================================")
        logLines.append("============================================")
        let outputText = logLines.joined(separator: "\n") + "\n"
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent("kamihi-parity-test-results.txt")
            try? outputText.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        try? outputText.write(toFile: "/tmp/kamihi-parity-test-results.txt", atomically: true, encoding: .utf8)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.currentMode {
                case .none:
                    if shouldShowSetup {
                        DesktopSetupView(
                            onFinish: {
                                deferredSetupThisLaunch = true
                                if setupPreviewStep == nil && desktop.isExternalDisplayConnected {
                                    DesktopLaunchProfile.selected.apply(to: desktop)
                                }
                                router.selectMode(.externalDesktop)
                            },
                            onLater: { deferredSetupThisLaunch = true },
                            initialStep: setupPreviewStep,
                            persistsProgress: setupPreviewStep == nil
                        )
                    } else {
                        ModeSelectionView()
                    }
                case .remoteMac:
                    // Kept only for legacy/debug launch arguments and integration regression testing.
                    // It is no longer exposed as a separate user-facing product in the normal app flow.
                    LegacyRemoteSessionRoot()
                case .externalDesktop:
                    ExternalDesktopRootView()
                }
            }
            .environmentObject(router)
            .environmentObject(desktop)
            .environmentObject(desktopRecovery)
            .statusBarHidden(false)
            .onChange(of: desktop.isExternalDisplayConnected) { _, connected in
                if connected {
                    _ = desktopRecovery.prepareForConnection(desktop: desktop)
                } else {
                    desktopRecovery.finishSession(desktop: desktop)
                }
            }
            .onChange(of: desktop.windows) { _, _ in
                desktopRecovery.autosave(desktop: desktop)
            }
        }
    }
}

/// Instantiate Bonjour/remote transport only when the legacy route is actually opened.
/// Constructing RemoteSession at App scope would start discovery during Desktop setup.
private struct LegacyRemoteSessionRoot: View {
    @StateObject private var session = RemoteSession()

    var body: some View {
        RemoteMacRootView()
            .environmentObject(session)
    }
}
