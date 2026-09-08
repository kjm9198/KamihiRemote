import Foundation
import OSLog
import UIKit

#if DEBUG
@MainActor
enum DesktopClipboardPointerSmoke {
    private static let logger = Logger(subsystem: "com.kamihi.remote", category: "ClipboardPointerSmoke")
    static let successMarker = "KAMIHI_CLIPBOARD_POINTER_OK"

    @discardableResult
    static func run(on desktop: DesktopSession) async -> Bool {
        guard ProcessInfo.processInfo.arguments.contains(DesktopClipboardLifecycleSmoke.launchArgument) else { return true }

        for title in ["Clipboard", "Notes", "Calculator"] {
            for window in desktop.windows.filter({ $0.title == title }) {
                desktop.close(window.id)
            }
        }

        UIPasteboard.general.items = []
        let clipboard = DesktopClipboardStore.shared
        clipboard.clear()
        let notes = DesktopNotesStore.shared
        if notes.activeNoteID == nil { notes.createNewNote() }
        notes.text = ""
        notes.focus(.body)

        let seed = "Kamihi pointer seed"
        UIPasteboard.general.string = seed

        let notesID = desktop.openProductivityApp(
            "Notes",
            frame: CGRect(x: 0.07, y: 0.09, width: 0.55, height: 0.72)
        )
        let clipboardID = desktop.openProductivityApp(
            "Clipboard",
            frame: CGRect(x: 0.38, y: 0.13, width: 0.54, height: 0.68)
        )

        guard desktop.activeWindowID == clipboardID else {
            return fail("setup", "Clipboard was not frontmost")
        }
        guard await waitForTarget(.itemCopy(seed)) != nil else {
            return fail("render", "Rendered Clipboard item controls never registered")
        }

        // Refresh must use the visible toolbar hit target rather than calling the
        // store directly. The new pasteboard value is intentionally uncaptured
        // until the software pointer clicks Refresh.
        let refreshed = "Kamihi pointer refreshed"
        UIPasteboard.general.string = refreshed
        guard await click(.toolbarRefresh, desktop: desktop, clipboardID: clipboardID) else {
            return fail("refresh-hit", "Refresh hit target was unavailable")
        }
        guard clipboard.items.first == refreshed else {
            return fail("refresh", "Pointer Refresh did not capture the current pasteboard")
        }
        guard await waitForTarget(.itemCopy(refreshed)) != nil else {
            return fail("refresh-render", "Refreshed item controls did not render")
        }

        UIPasteboard.general.string = "different system value"
        guard await click(.itemCopy(refreshed), desktop: desktop, clipboardID: clipboardID) else {
            return fail("copy-hit", "Copy hit target was unavailable")
        }
        guard UIPasteboard.general.string == refreshed, clipboard.items.first == refreshed else {
            return fail("copy", "Pointer Copy did not update the system clipboard/history")
        }

        notes.text = ""
        guard await click(.itemNotes(refreshed), desktop: desktop, clipboardID: clipboardID) else {
            return fail("notes-hit", "Notes hit target was unavailable")
        }
        guard desktop.activeWindowID == notesID, notes.text == refreshed else {
            return fail("notes", "Pointer Notes handoff did not append exactly once and focus Notes")
        }

        notes.focus(.body)
        desktop.restoreAndActivate(clipboardID)
        guard await waitForTarget(.itemPaste(refreshed)) != nil else {
            return fail("paste-render", "Paste hit target was unavailable after restoring Clipboard")
        }
        let beforePaste = notes.text
        guard await click(.itemPaste(refreshed), desktop: desktop, clipboardID: clipboardID) else {
            return fail("paste-hit", "Pointer Paste target did not execute")
        }
        guard desktop.activeWindowID == notesID,
              notes.text == beforePaste + refreshed else {
            return fail("paste", "Pointer Paste did not insert exactly once into the adjacent Notes editor")
        }

        // Share is deliberately presented on the interactive main-screen scene,
        // never the passive external display. Wait for UIKit's actual presentation
        // state instead of assuming a fixed CI timing, and resolve the same visible
        // fallback window that production uses when no main-screen window is key.
        desktop.restoreAndActivate(clipboardID)
        guard await waitForTarget(.itemShare(refreshed)) != nil else {
            return fail("share-render", "Share hit target was unavailable")
        }
        guard await click(.itemShare(refreshed), desktop: desktop, clipboardID: clipboardID) else {
            return fail("share-hit", "Pointer Share target did not execute")
        }
        guard let activity = await waitForPresentedActivityController() else {
            return fail("share", "Pointer Share did not present UIActivityViewController on the interactive scene")
        }
        activity.dismiss(animated: false)
        guard await waitForActivityControllerDismissal() else {
            return fail("share-dismiss", "Share sheet did not dismiss before the remaining Clipboard flow")
        }

        // Force a long list and verify the explicitly registered native Clipboard
        // ScrollView owns wheel/two-finger deltas while Clipboard is frontmost.
        for index in 0..<20 {
            clipboard.copy("Kamihi scroll item \(index)")
        }
        desktop.restoreAndActivate(clipboardID)
        guard await waitForTarget(.itemCopy("Kamihi scroll item 19")) != nil else {
            return fail("scroll-render", "Long Clipboard history did not render")
        }
        guard let window = desktop.windows.first(where: { $0.id == clipboardID }) else {
            return fail("scroll-window", "Clipboard window disappeared")
        }
        let frame = desktop.effectiveFrame(for: window)
        desktop.cursor = CGPoint(x: frame.midX, y: frame.midY)
        let beforeScroll = DesktopNativeScrollRegistry.shared.logicalContentOffset(for: "Clipboard").y
        guard DesktopNativeScrollRegistry.shared.scroll(key: "Clipboard", deltaX: 0, deltaY: 280) else {
            return fail("scroll-route", "Clipboard native scroll registry did not own the scroll")
        }
        guard await waitForScrollAdvance(from: beforeScroll) else {
            return fail("scroll", "Clipboard long-history scroll offset did not advance")
        }

        // End with the destructive Clear confirmation visible. The smoke checks
        // that the pointer only requests confirmation and does not bypass safety.
        guard await click(.toolbarClear, desktop: desktop, clipboardID: clipboardID) else {
            return fail("clear-hit", "Clear hit target was unavailable")
        }
        guard !clipboard.items.isEmpty else {
            return fail("clear-safety", "Pointer Clear bypassed the confirmation and erased history immediately")
        }

        logger.notice("\(successMarker, privacy: .public)")
        print(successMarker)
        return true
    }

    private static func waitForTarget(
        _ target: DesktopClipboardHitRegistry.Target,
        attempts: Int = 50
    ) async -> DesktopClipboardHitRegistry.Entry? {
        for _ in 0..<attempts {
            if let entry = DesktopClipboardHitRegistry.shared.entries.first(where: { $0.target == target }),
               entry.normalizedFrame.width > 0,
               entry.normalizedFrame.height > 0 {
                return entry
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private static func click(
        _ target: DesktopClipboardHitRegistry.Target,
        desktop: DesktopSession,
        clipboardID: UUID
    ) async -> Bool {
        guard let entry = await waitForTarget(target),
              let window = desktop.windows.first(where: { $0.id == clipboardID }) else { return false }

        desktop.restoreAndActivate(clipboardID)
        let frame = desktop.effectiveFrame(for: window)
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        let contentHeight = frame.maxY - contentTop
        let center = CGPoint(x: entry.normalizedFrame.midX, y: entry.normalizedFrame.midY)
        desktop.cursor = CGPoint(
            x: frame.minX + center.x * frame.width,
            y: contentTop + center.y * contentHeight
        )
        desktop.clickAtCursor()
        await Task.yield()
        return true
    }

    private static func waitForPresentedActivityController(
        attempts: Int = 50
    ) async -> UIActivityViewController? {
        for _ in 0..<attempts {
            if let activity = presentedActivityController() { return activity }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private static func waitForActivityControllerDismissal(
        attempts: Int = 50
    ) async -> Bool {
        for _ in 0..<attempts {
            if presentedActivityController() == nil { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func waitForScrollAdvance(
        from initialOffset: CGFloat,
        attempts: Int = 30
    ) async -> Bool {
        for _ in 0..<attempts {
            let current = DesktopNativeScrollRegistry.shared.logicalContentOffset(for: "Clipboard").y
            if current > initialOffset + 0.5 { return true }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private static func presentedActivityController() -> UIActivityViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive && $0.screen === UIScreen.main }
        let windows = scenes.flatMap(\.windows)
        let root = (
            windows.first(where: { $0.isKeyWindow })
            ?? windows.first(where: { !$0.isHidden && $0.alpha > 0.01 })
        )?.rootViewController
        return topPresented(from: root) as? UIActivityViewController
    }

    private static func topPresented(from root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }
        if let presented = root.presentedViewController { return topPresented(from: presented) }
        if let navigation = root as? UINavigationController { return topPresented(from: navigation.visibleViewController) }
        if let tabs = root as? UITabBarController { return topPresented(from: tabs.selectedViewController) }
        return root
    }

    private static func fail(_ step: String, _ message: String) -> Bool {
        let diagnostic = "KAMIHI_CLIPBOARD_POINTER_FAIL [\(step)] \(message)"
        logger.error("\(diagnostic, privacy: .public)")
        print(diagnostic)
        return false
    }
}
#endif
