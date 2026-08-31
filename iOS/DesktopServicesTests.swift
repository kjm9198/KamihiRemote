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
            try check("windowThirdFrames", windowThirdFrames)
            try check("windowCycling", windowCycling)
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
}
