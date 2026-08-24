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
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
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
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        engine?.markUIKitTouch()
        forward(event, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        engine?.markUIKitTouch()
        forward(event, phase: .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        engine?.markUIKitTouch()
        forward(event, phase: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        engine?.handleCancelled(in: bounds.size)
    }

    private func forward(_ event: UIEvent?, phase: UITouch.Phase) {
        guard let event else { return }
        let points = (event.touches(for: self) ?? [])
            .filter { $0.phase != .cancelled && $0.phase != .ended }
            .map { $0.location(in: self) }
        let timestamp = event.timestamp

        switch phase {
        case .began:
            let beganPoints = points.isEmpty ? event.allTouches.map(locations) ?? [] : points
            engine?.handleBegan(points: beganPoints, timestamp: timestamp, in: bounds.size)
        case .moved:
            engine?.handleMoved(points: points, timestamp: timestamp, in: bounds.size)
        case .ended:
            engine?.handleEnded(remainingCount: points.count, timestamp: timestamp, in: bounds.size)
        default:
            break
        }
    }

    private func locations(_ touches: Set<UITouch>) -> [CGPoint] {
        touches.map { $0.location(in: self) }
    }
}
