import CoreGraphics
import Foundation

@MainActor
enum DesktopServicesTests {
    @discardableResult
    static func runSelfChecks() -> Bool {
        do {
            try check("displayMetrics16x9", displayMetrics16x9)
            try check("displayMetricsUltrawide", displayMetricsUltrawide)
            try check("workspacePersistenceShape", workspacePersistenceShape)
            try check("recoverySnapshotRoundTrip", recoverySnapshotRoundTrip)
            try check("windowThirdFrames", windowThirdFrames)
            try check("windowCycling", windowCycling)
            try check("windowResizeBounds", windowResizeBounds)
            try check("windowOverviewBulkActions", windowOverviewBulkActions)
            NSLog("Kamihi desktop services self-checks passed")
            return true
        } catch {
            NSLog("Kamihi desktop services self-check FAILED: %@", String(describing: error))
            return false
        }
    }

    private struct CheckError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckError(message: message) }
    }

    private static func check(_ name: String, _ body: () throws -> Void) throws {
        do { try body() }
        catch { throw CheckError(message: "\(name): \(error)") }
    }

    private static func displayMetrics16x9() throws {
        let metrics = DesktopDisplayMetrics(size: CGSize(width: 1920, height: 1080), scale: 1)
        try require(metrics.classification == "16:9 / glasses", "1080p should use glasses/16:9 profile")
        try require(abs(metrics.aspectRatio - (16.0 / 9.0)) < 0.01, "aspect ratio should be 16:9")
    }

    private static func displayMetricsUltrawide() throws {
        let metrics = DesktopDisplayMetrics(size: CGSize(width: 3440, height: 1440), scale: 1)
        try require(metrics.classification == "Ultrawide", "3440x1440 should classify as ultrawide")
        try require(metrics.recommendedScale >= 1.2, "large display should increase UI scale recommendation")
    }

    private static func workspacePersistenceShape() throws {
        let item = DesktopFeatureState.SavedWindow(
            title: "ChatGPT",
            x: 0.1,
            y: 0.1,
            width: 0.5,
            height: 0.8,
            minimized: false,
            maximized: false
        )
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([DesktopFeatureState.SavedWindow].self, from: data)
        try require(decoded == [item], "saved windows must round-trip")
    }

    private static func recoverySnapshotRoundTrip() throws {
        let desktop = DesktopSession.shared
        desktop.closeAllDesktopWindows()
        _ = desktop.openProductivityApp(
            "ChatGPT",
            frame: CGRect(x: 0.08, y: 0.07, width: 0.84, height: 0.79)
        )
        let savedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = DesktopRecoveryCoordinator.makeSnapshot(
            desktop: desktop,
            workspace: .focus,
            savedAt: savedAt
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = DesktopRecoveryCoordinator.decodeSnapshot(data)
        try require(decoded == snapshot, "recovery snapshot must round-trip without losing window state")
        try require(decoded?.workspaceRawValue == DesktopFeatureState.Workspace.focus.rawValue, "recovery snapshot must preserve workspace")
        try require(decoded?.windows.first?.title == "ChatGPT", "recovery snapshot must preserve app identity")
        desktop.closeAllDesktopWindows()
    }

    private static func windowThirdFrames() throws {
        let desktop = DesktopSession.shared
        desktop.closeAllDesktopWindows()
        let id = desktop.openProductivityApp("Test")
        desktop.activate(id)
        desktop.snapActiveThird(0)
        let first = desktop.windows.first(where: { $0.id == id })!.normalizedFrame
        desktop.snapActiveThird(2)
        let third = desktop.windows.first(where: { $0.id == id })!.normalizedFrame
        try require(first.minX < third.minX, "third snapping must move window horizontally")
        try require(abs(first.width - third.width) < 0.001, "third snapping widths must match")
        desktop.closeAllDesktopWindows()
    }

    private static func windowCycling() throws {
        let desktop = DesktopSession.shared
        desktop.closeAllDesktopWindows()
        let first = desktop.openProductivityApp("One")
        let second = desktop.openProductivityApp("Two")
        desktop.activate(first)
        desktop.cycleWindow()
        try require(desktop.activeWindowID == second, "cycling forward should activate next visible window")
        desktop.closeAllDesktopWindows()
    }

    private static func windowResizeBounds() throws {
        let desktop = DesktopSession.shared
        desktop.closeAllDesktopWindows()
        let id = desktop.openProductivityApp("Resize", frame: CGRect(x: 0.20, y: 0.12, width: 0.50, height: 0.50))
        desktop.activate(id)
        desktop.resizeActive(widthDelta: 5, heightDelta: 5)
        var frame = desktop.windows.first(where: { $0.id == id })!.normalizedFrame
        try require(frame.maxX <= 0.9761, "resized window must remain inside right desktop boundary")
        try require(frame.maxY <= 0.8901, "resized window must remain above taskbar boundary")

        desktop.resizeActive(widthDelta: -5, heightDelta: -5)
        frame = desktop.windows.first(where: { $0.id == id })!.normalizedFrame
        try require(frame.width >= 0.279, "window width must respect minimum")
        try require(frame.height >= 0.239, "window height must respect minimum")

        desktop.centerActiveWindow()
        frame = desktop.windows.first(where: { $0.id == id })!.normalizedFrame
        try require(abs(frame.midX - 0.5) < 0.02, "center action must horizontally center active window")
        desktop.closeAllDesktopWindows()
    }

    private static func windowOverviewBulkActions() throws {
        let desktop = DesktopSession.shared
        desktop.closeAllDesktopWindows()
        _ = desktop.openProductivityApp("One")
        _ = desktop.openProductivityApp("Two")
        desktop.minimizeAllWindows()
        try require(desktop.windows.allSatisfy(\.isMinimized), "minimize all must minimize every window")
        try require(desktop.activeWindowID == nil, "minimize all should clear active window")
        desktop.restoreAllWindows()
        try require(desktop.windows.allSatisfy { !$0.isMinimized }, "restore all must restore every window")
        try require(desktop.activeWindowID != nil, "restore all should activate a window")
        desktop.closeAllDesktopWindows()
    }
}
