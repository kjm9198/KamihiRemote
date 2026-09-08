import SwiftUI
import UIKit

/// Tracks the real rendered controls inside the native Clipboard app so the
/// iPhone software pointer can activate exactly the same actions as touch.
/// Frames are normalized to the current Clipboard content size, which keeps hit
/// testing correct when the window is resized and on iPad layouts.
@MainActor
final class DesktopClipboardHitRegistry {
    static let shared = DesktopClipboardHitRegistry()

    enum Target: Hashable {
        case toolbarRefresh
        case toolbarClear
        case itemPaste(String)
        case itemCopy(String)
        case itemNotes(String)
        case itemShare(String)
    }

    struct Entry: Equatable {
        let target: Target
        let normalizedFrame: CGRect
    }

    private(set) var entries: [Entry] = []
    var onClearRequested: (() -> Void)?

    private init() {}

    func update(entries: [Entry]) {
        guard self.entries != entries else { return }
        self.entries = entries
    }

    func clear() {
        if !entries.isEmpty { entries.removeAll() }
        onClearRequested = nil
    }

    func hitTest(at normalizedPoint: CGPoint) -> Target? {
        for entry in entries.reversed() {
            if entry.normalizedFrame.insetBy(dx: -0.0025, dy: -0.0025).contains(normalizedPoint) {
                return entry.target
            }
        }
        return nil
    }

    @discardableResult
    func perform(_ target: Target, desktop: DesktopSession) -> Bool {
        let clipboard = DesktopClipboardStore.shared
        switch target {
        case .toolbarRefresh:
            clipboard.captureIfChanged()
        case .toolbarClear:
            guard (!clipboard.items.isEmpty || !UIPasteboard.general.items.isEmpty),
                  onClearRequested != nil else { return false }
            onClearRequested?()
        case .itemPaste(let item):
            return desktop.pasteClipboardItemIntoPreviousApp(item)
        case .itemCopy(let item):
            clipboard.copy(item)
        case .itemNotes(let item):
            let notes = DesktopNotesStore.shared
            if notes.activeNoteID == nil { notes.createNewNote() }
            let body = notes.activeNote?.body ?? ""
            if !body.isEmpty { notes.appendToActiveBody("\n\n") }
            notes.appendToActiveBody(item)
            notes.focus(.body)
            desktop.openNotes()
        case .itemShare(let item):
            return DesktopClipboardSharePresenter.present(item)
        }
        return true
    }
}

struct DesktopClipboardHitPreference: Equatable {
    let target: DesktopClipboardHitRegistry.Target
    let normalizedFrame: CGRect
}

struct DesktopClipboardHitPreferenceKey: PreferenceKey {
    static var defaultValue: [DesktopClipboardHitPreference] = []

    static func reduce(
        value: inout [DesktopClipboardHitPreference],
        nextValue: () -> [DesktopClipboardHitPreference]
    ) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func desktopClipboardHitTarget(
        _ target: DesktopClipboardHitRegistry.Target,
        containerSize: CGSize
    ) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named("desktopClipboardContent"))
                let normalized = containerSize.width > 0 && containerSize.height > 0
                    ? CGRect(
                        x: frame.minX / containerSize.width,
                        y: frame.minY / containerSize.height,
                        width: frame.width / containerSize.width,
                        height: frame.height / containerSize.height
                    )
                    : .zero

                Color.clear.preference(
                    key: DesktopClipboardHitPreferenceKey.self,
                    value: [DesktopClipboardHitPreference(target: target, normalizedFrame: normalized)]
                )
            }
        }
    }
}

@MainActor
extension DesktopSession {
    /// Resolve software-pointer clicks only after normal top-window ownership has
    /// selected Clipboard. A covered/background Clipboard can never steal input.
    func handleClipboardClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        let contentHeight = frame.maxY - contentTop
        guard frame.width > 0,
              contentHeight > 0,
              point.x >= frame.minX,
              point.x <= frame.maxX,
              point.y > contentTop,
              point.y <= frame.maxY else {
            wantsPhoneKeyboard = false
            return
        }

        wantsPhoneKeyboard = false
        let localPoint = CGPoint(
            x: (point.x - frame.minX) / frame.width,
            y: (point.y - contentTop) / contentHeight
        )
        guard let target = DesktopClipboardHitRegistry.shared.hitTest(at: localPoint) else { return }
        if DesktopClipboardHitRegistry.shared.perform(target, desktop: self),
           TrackpadSettings.shared.hapticsEnabled {
            Haptics.touchTap()
        }
    }
}

/// Software-pointer Share should appear on the interactive iPhone/iPad scene,
/// not on the noninteractive external display. This uses only public UIKit APIs
/// and never retains or uploads the clipboard text itself.
@MainActor
private enum DesktopClipboardSharePresenter {
    @discardableResult
    static func present(_ text: String) -> Bool {
        guard !text.isEmpty,
              let presenter = foregroundMainScreenPresenter() else { return false }

        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
        return true
    }

    private static func foregroundMainScreenPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive && $0.screen === UIScreen.main }

        let window = scenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
            ?? scenes.flatMap(\.windows).first(where: { !$0.isHidden && $0.alpha > 0.01 })

        guard let root = window?.rootViewController else { return nil }
        return topPresenter(from: root)
    }

    private static func topPresenter(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topPresenter(from: presented)
        }
        if let navigation = root as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topPresenter(from: visible)
        }
        if let tabs = root as? UITabBarController,
           let selected = tabs.selectedViewController {
            return topPresenter(from: selected)
        }
        return root
    }
}
