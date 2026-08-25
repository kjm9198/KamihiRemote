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
    private var nextIdentity = 1

    override func layoutSubviews() {
        super.layoutSubviews()
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        engine?.noteCanvasSize(bounds.size)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { identity(for: touch) }
        forward(changed: touches, event: event, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(changed: touches, event: event, phase: .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(changed: touches, event: event, phase: .ended)
        for touch in touches { identities[ObjectIdentifier(touch)] = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(changed: touches, event: event, phase: .cancelled)
        for touch in touches { identities[ObjectIdentifier(touch)] = nil }
    }

    private func forward(changed: Set<UITouch>, event: UIEvent?, phase: UITouch.Phase) {
        // Only touches that belong to this trackpad view — never other chrome buttons.
        let all = event?.touches(for: self) ?? changed
        let activeTouches: [UITouch]
        if phase == .ended || phase == .cancelled {
            activeTouches = all.filter { touch in
                !changed.contains(touch) && (touch.phase == .began || touch.phase == .moved || touch.phase == .stationary)
            }
        } else {
            activeTouches = Array(all.filter { $0.phase != .ended && $0.phase != .cancelled })
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
