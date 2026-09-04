import SwiftUI

/// Hardware-keyboard commands for the normal iPhone-first Desktop scene.
///
/// The controls stay visually hidden so the phone remains a full-screen trackpad,
/// while SwiftUI still registers the commands with the active scene and exposes
/// their button titles through iPadOS keyboard-shortcut discoverability.
/// Control-Option is deliberately avoided because VoiceOver reserves that chord.
struct DesktopHardwareShortcutLayer: View {
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        VStack(spacing: 0) {
            shortcutButton(
                "Close Active Window",
                key: "w",
                modifiers: [.command],
                action: closeActiveWindow
            )

            shortcutButton(
                "Minimize Active Window",
                key: "m",
                modifiers: [.command],
                action: minimizeActiveWindow
            )

            shortcutButton(
                "Next Window",
                key: "`",
                modifiers: [.command]
            ) {
                cycleWindow(forward: true)
            }

            shortcutButton(
                "Previous Window",
                key: "`",
                modifiers: [.command, .shift]
            ) {
                cycleWindow(forward: false)
            }

            shortcutButton(
                "Tile Window Left",
                key: .leftArrow,
                modifiers: [.command, .control]
            ) {
                snapActiveWindow(to: .leftHalf)
            }

            shortcutButton(
                "Tile Window Right",
                key: .rightArrow,
                modifiers: [.command, .control]
            ) {
                snapActiveWindow(to: .rightHalf)
            }

            shortcutButton(
                "Maximize or Restore Window",
                key: .upArrow,
                modifiers: [.command, .control],
                action: toggleActiveWindowMaximize
            )

            shortcutButton(
                "Arrange Visible Windows",
                key: "a",
                modifiers: [.command, .control],
                action: arrangeVisibleWindows
            )
        }
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func shortcutButton(
        _ title: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .keyboardShortcut(key, modifiers: modifiers)
            .disabled(desktop.activeWindowID == nil)
    }

    private func closeActiveWindow() {
        guard let id = desktop.activeWindowID else { return }
        // A hardware close command must never leave the phone's software-keyboard
        // proxy targeting a window that no longer exists.
        desktop.dismissPhoneKeyboardRequest()
        desktop.close(id)
    }

    private func minimizeActiveWindow() {
        guard let id = desktop.activeWindowID else { return }
        // Minimize is also a focus transition: clear the phone keyboard request
        // before DesktopSession promotes the next visible window.
        desktop.dismissPhoneKeyboardRequest()
        desktop.minimize(id)
    }

    private func cycleWindow(forward: Bool) {
        // Window switching is an explicit focus transition. Clear any outstanding
        // software-keyboard request before moving focus so text cannot redirect.
        desktop.dismissPhoneKeyboardRequest()
        desktop.cycleWindow(forward: forward)
    }

    private func snapActiveWindow(to target: WindowSnapEngine.SnapTarget) {
        guard let id = desktop.activeWindowID else { return }
        desktop.snapWindow(id, to: target)
    }

    private func toggleActiveWindowMaximize() {
        guard let id = desktop.activeWindowID else { return }
        desktop.toggleMaximize(id)
    }

    /// Tiles the currently visible working set without launching, closing, or
    /// restoring any other app. Two windows become halves, three become thirds,
    /// and four become quarters. Larger sets are deliberately left unchanged so
    /// a shortcut can never unexpectedly hide or overlap extra work.
    private func arrangeVisibleWindows() {
        let visibleIDs = desktop.windows
            .filter { !$0.isMinimized }
            .map(\.id)

        let targets: [WindowSnapEngine.SnapTarget]
        switch visibleIDs.count {
        case 2:
            targets = [.leftHalf, .rightHalf]
        case 3:
            targets = [.leftThird, .centerThird, .rightThird]
        case 4:
            targets = [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]
        default:
            return
        }

        let previouslyActiveID = desktop.activeWindowID
        desktop.dismissPhoneKeyboardRequest()

        for (id, target) in zip(visibleIDs, targets) {
            desktop.snapWindow(id, to: target)
        }

        if let previouslyActiveID,
           visibleIDs.contains(previouslyActiveID) {
            desktop.restoreAndActivate(previouslyActiveID)
        }
    }
}
