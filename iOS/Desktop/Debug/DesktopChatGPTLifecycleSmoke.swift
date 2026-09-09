import Foundation
import OSLog

#if DEBUG
@MainActor
enum DesktopChatGPTLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")
    private static let markerURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("kamihi-chatgpt-lifecycle-smoke.txt", isDirectory: false)

    @discardableResult
    static func run(desktop: DesktopSession = .shared) -> Bool {
        try? FileManager.default.removeItem(at: markerURL)

        let originalWindows = desktop.windows
        let originalActiveID = desktop.activeWindowID
        let originalKeyboardRequest = desktop.wantsPhoneKeyboard

        defer {
            desktop.windows = originalWindows
            desktop.activeWindowID = originalActiveID
            desktop.wantsPhoneKeyboard = originalKeyboardRequest
        }

        desktop.windows = originalWindows.filter { $0.title != "ChatGPT" }
        if desktop.activeWindowID.flatMap({ id in desktop.windows.contains(where: { $0.id == id }) }) != true {
            desktop.activeWindowID = desktop.windows.last(where: { !$0.isMinimized })?.id
        }

        let firstID = desktop.openProductivityApp(
            "ChatGPT",
            frame: CGRect(x: 0.14, y: 0.10, width: 0.68, height: 0.70)
        )
        guard let opened = desktop.windows.first(where: { $0.id == firstID }),
              opened.title == "ChatGPT",
              !opened.isMinimized,
              desktop.activeWindowID == firstID else {
            return fail("open")
        }

        desktop.minimize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMinimized == true,
              desktop.activeWindowID != firstID else {
            return fail("minimize")
        }

        let restoredID = desktop.openProductivityApp("ChatGPT")
        guard restoredID == firstID,
              desktop.activeWindowID == firstID,
              desktop.windows.first(where: { $0.id == firstID })?.isMinimized == false else {
            return fail("restore")
        }

        desktop.toggleMaximize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMaximized == true,
              desktop.activeWindowID == firstID else {
            return fail("maximize")
        }

        desktop.toggleMaximize(firstID)
        guard desktop.windows.first(where: { $0.id == firstID })?.isMaximized == false else {
            return fail("restore-size")
        }

        desktop.close(firstID)
        guard !desktop.windows.contains(where: { $0.id == firstID }),
              desktop.activeWindowID != firstID else {
            return fail("close")
        }

        let reopenedID = desktop.openProductivityApp("ChatGPT")
        guard reopenedID != firstID,
              desktop.activeWindowID == reopenedID,
              desktop.windows.first(where: { $0.id == reopenedID })?.title == "ChatGPT" else {
            return fail("reopen")
        }

        desktop.close(reopenedID)
        guard !desktop.windows.contains(where: { $0.id == reopenedID }) else {
            return fail("final-close")
        }

        emit("KAMIHI_CHATGPT_LIFECYCLE_OK")
        return true
    }

    private static func fail(_ step: String) -> Bool {
        emit("KAMIHI_CHATGPT_LIFECYCLE_FAIL [\(step)]")
        return false
    }

    private static func emit(_ marker: String) {
        if marker.hasPrefix("KAMIHI_CHATGPT_LIFECYCLE_FAIL") {
            logger.error("\(marker, privacy: .public)")
        } else {
            logger.notice("\(marker, privacy: .public)")
        }
        print(marker)

        do {
            try Data((marker + "\n").utf8).write(to: markerURL, options: .atomic)
        } catch {
            logger.error("KAMIHI_CHATGPT_LIFECYCLE_MARKER_WRITE_FAIL [\(error.localizedDescription, privacy: .public)]")
            print("KAMIHI_CHATGPT_LIFECYCLE_MARKER_WRITE_FAIL [\(error.localizedDescription)]")
        }
    }
}
#endif
