import SwiftUI
import UIKit

struct TrackpadView: UIViewRepresentable {
    let engine: TouchInputEngine

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.engine = engine
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isMultipleTouchEnabled = true
        view.isExclusiveTouch = false
        view.isUserInteractionEnabled = true
        view.accessibilityLabel = "Mac trackpad"
        view.accessibilityHint = "Move one finger to control the Mac pointer. Two fingers scroll. Three fingers change desktops."
        view.accessibilityTraits = .allowsDirectInteraction
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.engine = engine
        uiView.isUserInteractionEnabled = true
        uiView.isMultipleTouchEnabled = true
    }
}

final class TrackpadUIView: UIView {
    weak var engine: TouchInputEngine?
    private var identities: [ObjectIdentifier: Int] = [:]
    private var tracked: [ObjectIdentifier: UITouch] = [:]
    private var nextIdentity = 1
    private var reapLink: CADisplayLink?

    override func layoutSubviews() {
        super.layoutSubviews()
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        engine?.noteCanvasSize(bounds.size)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            reapLink?.invalidate()
            reapLink = nil
            forceEndAll()
        } else if reapLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(reapFrame))
            link.add(to: .main, forMode: .common)
            reapLink = link
        }
    }

    deinit {
        reapLink?.invalidate()
    }

    @objc private func reapFrame() {
        guard tracked.isEmpty == false else { return }
        reapFinishedTouches(except: [])
        if liveTouches().isEmpty { forceEndAll() }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            identity(for: touch)
            tracked[ObjectIdentifier(touch)] = touch
        }
        reapFinishedTouches(except: touches)
        forward(changed: touches, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { tracked[ObjectIdentifier(touch)] = touch }
        reapFinishedTouches(except: [])
        forward(changed: touches, phase: .moved)
        if liveTouches().isEmpty { forceEndAll() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(changed: touches, phase: .ended)
        forget(touches)
        if liveTouches().isEmpty { forceEndAll() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(changed: touches, phase: .cancelled)
        forget(touches)
        if liveTouches().isEmpty { forceEndAll() }
    }

    /// iOS sometimes never delivers `touchesEnded`. Poll tracked UITouch phases and close them.
    private func reapFinishedTouches(except keep: Set<UITouch>) {
        let finished = tracked.values.filter { touch in
            keep.contains(touch) == false && (touch.phase == .ended || touch.phase == .cancelled)
        }
        guard finished.isEmpty == false else { return }
        let set = Set(finished)
        forward(changed: set, phase: .ended)
        forget(set)
    }

    private func liveTouches() -> [UITouch] {
        tracked.values.filter { touch in
            touch.phase != .ended && touch.phase != .cancelled
        }
    }

    private func forget(_ touches: Set<UITouch>) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            tracked[key] = nil
            identities[key] = nil
        }
    }

    private func forceEndAll() {
        guard tracked.isEmpty == false || identities.isEmpty == false else { return }
        engine?.handleCancelled(in: bounds.size)
        tracked.removeAll(keepingCapacity: true)
        identities.removeAll(keepingCapacity: true)
    }

    private func forward(changed: Set<UITouch>, phase: UITouch.Phase) {
        let activeTouches: [UITouch]
        if phase == .ended || phase == .cancelled {
            activeTouches = liveTouches().filter { changed.contains($0) == false }
        } else {
            activeTouches = liveTouches()
        }
        let changedSamples = changed.map(sample)
        let activeSamples = activeTouches.map(sample)
        let timestamp = changed.first?.timestamp ?? ProcessInfo.processInfo.systemUptime
        engine?.handle(changed: changedSamples, active: activeSamples, timestamp: timestamp, phase: phase, in: bounds.size)
    }

    private func sample(_ touch: UITouch) -> FingerSample {
        // preciseLocation tracks the fingertip more closely than the coarse contact point.
        let point = touch.preciseLocation(in: self)
        return FingerSample(id: identity(for: touch), point: point, phase: touch.phase)
    }

    @discardableResult
    private func identity(for touch: UITouch) -> Int {
        let key = ObjectIdentifier(touch)
        if let existing = identities[key] { return existing }
        let value = nextIdentity
        nextIdentity += 1
        identities[key] = value
        return value
    }
}
