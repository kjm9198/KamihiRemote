import Foundation
import OSLog

#if DEBUG
@MainActor
enum DesktopCalculatorLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "CalculatorSmoke")
    static let launchArgument = "-KamihiCalculatorLifecycleSmoke"
    static let successMarker = "KAMIHI_CALCULATOR_LIFECYCLE_OK"

    @discardableResult
    static func run(on desktop: DesktopSession) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return true }

        // Start from a deterministic app state without touching the user's normal
        // persistent Desktop path. This harness is DEBUG-only and is invoked only
        // by the simulator smoke launch argument.
        if let existing = desktop.windows.first(where: { $0.title == "Calculator" }) {
            desktop.close(existing.id)
        }

        let calculator = DesktopCalculatorStore.shared
        calculator.clear()

        let firstID = desktop.openProductivityApp(
            "Calculator",
            frame: CGRect(x: 0.28, y: 0.12, width: 0.44, height: 0.70)
        )
        guard assertWindow(desktop, id: firstID, minimized: false, maximized: false, active: true, step: "open") else { return false }

        desktop.minimize(firstID)
        guard assertWindow(desktop, id: firstID, minimized: true, maximized: false, active: false, step: "minimize") else { return false }

        desktop.restoreAndActivate(firstID)
        guard assertWindow(desktop, id: firstID, minimized: false, maximized: false, active: true, step: "restore") else { return false }

        desktop.toggleMaximize(firstID)
        guard assertWindow(desktop, id: firstID, minimized: false, maximized: true, active: true, step: "maximize") else { return false }

        desktop.toggleMaximize(firstID)
        guard assertWindow(desktop, id: firstID, minimized: false, maximized: false, active: true, step: "restore-from-maximize") else { return false }

        for token in ["1", "2", "×", "(", "3", "+", "4", ")"] {
            calculator.append(token)
        }
        calculator.evaluate()
        guard calculator.result == "84" else {
            return fail("calculate", "expected 84, got \(calculator.result)")
        }

        desktop.close(firstID)
        guard !desktop.windows.contains(where: { $0.id == firstID }), desktop.activeWindowID != firstID else {
            return fail("close", "closed Calculator still owns a window or focus")
        }

        let reopenedID = desktop.openProductivityApp(
            "Calculator",
            frame: CGRect(x: 0.28, y: 0.12, width: 0.44, height: 0.70)
        )
        guard reopenedID != firstID else {
            return fail("reopen", "close/reopen reused the removed window identity")
        }
        guard assertWindow(desktop, id: reopenedID, minimized: false, maximized: false, active: true, step: "reopen") else { return false }
        guard calculator.result == "84", calculator.expression == "12×(3+4)" else {
            return fail("reopen", "Calculator value did not survive a window close/reopen in the same desktop session")
        }

        logger.notice("\(successMarker, privacy: .public)")
        print(successMarker)
        return true
    }

    private static func assertWindow(
        _ desktop: DesktopSession,
        id: UUID,
        minimized: Bool,
        maximized: Bool,
        active: Bool,
        step: String
    ) -> Bool {
        guard let window = desktop.windows.first(where: { $0.id == id }) else {
            return fail(step, "Calculator window is missing")
        }
        guard window.title == "Calculator" else {
            return fail(step, "wrong window title: \(window.title)")
        }
        guard window.isMinimized == minimized else {
            return fail(step, "minimized=\(window.isMinimized), expected \(minimized)")
        }
        guard window.isMaximized == maximized else {
            return fail(step, "maximized=\(window.isMaximized), expected \(maximized)")
        }
        guard (desktop.activeWindowID == id) == active else {
            return fail(step, "active ownership mismatch")
        }
        return true
    }

    private static func fail(_ step: String, _ message: String) -> Bool {
        logger.error("KAMIHI_CALCULATOR_LIFECYCLE_FAIL [\(step, privacy: .public)] \(message, privacy: .public)")
        assertionFailure("Calculator lifecycle smoke failed at \(step): \(message)")
        return false
    }
}
#endif
