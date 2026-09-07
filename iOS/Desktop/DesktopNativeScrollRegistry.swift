import SwiftUI
import UIKit

/// Bridges Kamihi's software trackpad to native SwiftUI/UIView scroll surfaces.
/// Web apps continue using DesktopWebInputRegistry; native apps register their
/// primary UIScrollView here so two-finger trackpad motion affects visible content.
@MainActor
final class DesktopNativeScrollRegistry {
    static let shared = DesktopNativeScrollRegistry()

    private final class WeakScrollView {
        weak var value: UIScrollView?
        init(_ value: UIScrollView) { self.value = value }
    }

    private var scrollViews: [String: WeakScrollView] = [:]

    private let autoDiscoverableApps: Set<String> = [
        "Documents", "Notes", "Files", "Photos", "Sheets", "Clipboard",
        "PDF Viewer", "Settings", "Display Diagnostics"
    ]

    private init() {}

    func register(_ scrollView: UIScrollView, key: String) {
        scrollViews[key] = WeakScrollView(scrollView)
    }

    func unregister(_ scrollView: UIScrollView, key: String) {
        guard scrollViews[key]?.value === scrollView else { return }
        scrollViews.removeValue(forKey: key)
    }

    @discardableResult
    func scroll(key: String, deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        let resolvedKey = resolvedScrollKey(for: key)
        return scrollResolved(key: resolvedKey, deltaX: deltaX, deltaY: deltaY)
    }

    /// Notes owns two independent scroll surfaces. The sidebar list and editor
    /// must never steal wheel/two-finger input from each other, so the cursor's
    /// visible pane selects the registered UIScrollView before applying deltas.
    /// Other native apps keep their existing one-key behavior.
    private func resolvedScrollKey(for key: String) -> String {
        guard key == "Notes",
              let activeWindow = DesktopSession.shared.activeWindow,
              activeWindow.title == "Notes" else { return key }

        let frame = DesktopSession.shared.effectiveFrame(for: activeWindow)
        let cursor = DesktopSession.shared.cursor
        guard frame.contains(cursor), frame.width > 0 else { return key }

        let localXInCanvasPoints = (cursor.x - frame.minX) * 1920
        if localXInCanvasPoints <= DesktopNotesLayoutMetrics.sidebarWidth {
            return "Notes.sidebar"
        }
        return "Notes.editor"
    }

    private func scrollResolved(key: String, deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        let scrollView: UIScrollView?
        if let registered = scrollViews[key]?.value {
            scrollView = registered
        } else {
            scrollViews.removeValue(forKey: key)
            scrollView = discoverVisibleScrollView(for: key)
            if let scrollView {
                register(scrollView, key: key)
            }
        }

        guard let scrollView else { return false }

        var target = scrollView.contentOffset
        target.x += deltaX
        target.y += deltaY

        let inset = scrollView.adjustedContentInset
        let minX = -inset.left
        let minY = -inset.top
        let maxX = max(minX, scrollView.contentSize.width - scrollView.bounds.width + inset.right)
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)

        target.x = min(max(target.x, minX), maxX)
        target.y = min(max(target.y, minY), maxY)
        scrollView.setContentOffset(target, animated: false)
        return true
    }

    /// SwiftUI can rebuild its private UIScrollView hierarchy as native app state
    /// changes (for example Photos grid -> detail -> grid, or Clipboard empty -> list).
    /// Explicit bridges remain the most deterministic path, but this public-UIKit
    /// fallback discovers the largest scrollable surface inside the active desktop
    /// window so newly-created native app scroll views do not silently stop working.
    private func discoverVisibleScrollView(for key: String) -> UIScrollView? {
        // Pane-specific keys such as Notes.sidebar/Notes.editor are intentionally
        // explicit-only. Falling back to the largest Notes scroll view could route
        // a sidebar wheel gesture into the editor, recreating the ownership bug.
        guard !key.contains("."),
              autoDiscoverableApps.contains(key),
              let activeWindow = DesktopSession.shared.activeWindow,
              activeWindow.title == key else { return nil }

        let normalizedFrame = DesktopSession.shared.effectiveFrame(for: activeWindow)
        var bestCandidate: UIScrollView?
        var bestScore: CGFloat = 0

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 0 && $0.bounds.height > 0 }
            .sorted { lhs, rhs in
                let lhsExternal = lhs.windowScene?.screen !== UIScreen.main
                let rhsExternal = rhs.windowScene?.screen !== UIScreen.main
                if lhsExternal != rhsExternal { return lhsExternal && !rhsExternal }
                return lhs.windowLevel.rawValue > rhs.windowLevel.rawValue
            }

        for window in windows {
            let appFrame = CGRect(
                x: normalizedFrame.minX * window.bounds.width,
                y: normalizedFrame.minY * window.bounds.height,
                width: normalizedFrame.width * window.bounds.width,
                height: normalizedFrame.height * window.bounds.height
            )

            for candidate in scrollViews(in: window) {
                guard !candidate.isHidden,
                      candidate.alpha > 0.01,
                      candidate.bounds.width > 1,
                      candidate.bounds.height > 1 else { continue }

                let inset = candidate.adjustedContentInset
                let scrollableWidth = candidate.contentSize.width + inset.left + inset.right > candidate.bounds.width + 1
                let scrollableHeight = candidate.contentSize.height + inset.top + inset.bottom > candidate.bounds.height + 1
                guard scrollableWidth || scrollableHeight else { continue }

                let candidateFrame = candidate.convert(candidate.bounds, to: window)
                let intersection = candidateFrame.intersection(appFrame)
                guard !intersection.isNull, !intersection.isEmpty else { continue }

                let intersectionArea = intersection.width * intersection.height
                let candidateArea = max(candidateFrame.width * candidateFrame.height, 1)
                let overlapRatio = intersectionArea / candidateArea
                guard overlapRatio > 0.40 else { continue }

                // Prefer the scroll surface that occupies most of the active app.
                // The small overlap bonus keeps nested text/preview scroll views from
                // beating the visible app-level surface merely because they are huge.
                let score = intersectionArea + overlapRatio * 10_000
                if score > bestScore {
                    bestScore = score
                    bestCandidate = candidate
                }
            }
        }

        return bestCandidate
    }

    private func scrollViews(in root: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []
        if let scrollView = root as? UIScrollView {
            result.append(scrollView)
        }
        for child in root.subviews {
            result.append(contentsOf: scrollViews(in: child))
        }
        return result
    }
}

/// Place this inside the content of the ScrollView that should own Kamihi
/// trackpad scrolling. It discovers the nearest UIKit UIScrollView without
/// relying on private APIs and registers it only while mounted.
struct DesktopNativeScrollBridge: UIViewRepresentable {
    let key: String

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.key = key
        return view
    }

    func updateUIView(_ uiView: AttachmentView, context: Context) {
        uiView.key = key
        uiView.registerNearestScrollView()
    }

    static func dismantleUIView(_ uiView: AttachmentView, coordinator: ()) {
        uiView.unregister()
    }

    final class AttachmentView: UIView {
        var key: String = ""
        private weak var registeredScrollView: UIScrollView?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { unregister() }
            else { registerNearestScrollView() }
        }

        func registerNearestScrollView() {
            guard !key.isEmpty else { return }
            var node = superview
            while let current = node {
                if let scrollView = current as? UIScrollView {
                    if registeredScrollView !== scrollView {
                        unregister()
                        registeredScrollView = scrollView
                        DesktopNativeScrollRegistry.shared.register(scrollView, key: key)
                    }
                    return
                }
                node = current.superview
            }

            DispatchQueue.main.async { [weak self] in
                self?.registerNearestScrollView()
            }
        }

        func unregister() {
            guard let scrollView = registeredScrollView, !key.isEmpty else {
                registeredScrollView = nil
                return
            }
            DesktopNativeScrollRegistry.shared.unregister(scrollView, key: key)
            registeredScrollView = nil
        }
    }
}
