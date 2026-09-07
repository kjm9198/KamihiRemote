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
        guard let scrollView = scrollViews[key]?.value else {
            scrollViews.removeValue(forKey: key)
            return false
        }

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
