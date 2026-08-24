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
        view.isExclusiveTouch = true
        view.isUserInteractionEnabled = true
        view.accessibilityLabel = "Mac trackpad"
        view.accessibilityHint = "Move one finger to control the Mac pointer. Two fingers scroll. Three fingers change desktops."
        view.accessibilityTraits = .allowsDirectInteraction
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.engine = engine
        uiView.isUserInteractionEnabled = true
    }
}

final class TrackpadUIView: UIView {
    weak var engine: TouchInputEngine?

    override func layoutSubviews() {
        super.layoutSubviews()
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        engine?.handleCancelled(in: bounds.size)
    }

    private func forward(_ touches: Set<UITouch>, phase: UITouch.Phase) {
        let samples = touches.map { FingerSample(id: $0.hash, point: $0.location(in: self)) }
        let timestamp = touches.first?.timestamp ?? ProcessInfo.processInfo.systemUptime
        engine?.handle(samples: samples, timestamp: timestamp, phase: phase, in: bounds.size)
    }
}
