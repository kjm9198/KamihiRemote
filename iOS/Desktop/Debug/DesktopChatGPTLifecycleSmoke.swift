import Foundation
import OSLog

#if DEBUG
@MainActor
enum DesktopChatGPTLifecycleSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "DesktopSmoke")

    @discardableResult
    static func run(desktop: DesktopSession = .shared) -> Bool {
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

        logger.notice("KAMIHI_CHATGPT_LIFECYCLE_OK")
        print("KAMIHI_CHATGPT_LIFECYCLE_OK")
        return true
    }

    private static func fail(_ step: String) -> Bool {
        logger.error("KAMIHI_CHATGPT_LIFECYCLE_FAIL [\(step, privacy: .public)]")
        print("KAMIHI_CHATGPT_LIFECYCLE_FAIL [\(step)]")
        return false
    }
}
#endif
