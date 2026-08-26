import SwiftUI

/// Kamihi-original multi-finger radial dot fields. Coordinates must match UITouch samples 1:1.
/// Hit testing is always disabled — this view is pure visualization.
struct DotFieldTouchView: View {
    let state: TouchAnimationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isVisuallyActive: Bool {
        state.fingers.isEmpty == false || state.lockedAction != nil || state.clickPulse > 0
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 / 20.0 : 1.0 / 60.0,
                paused: isVisuallyActive == false
            )
        ) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for finger in state.fingers.prefix(4) {
                    drawField(for: finger, in: &context, size: size, time: time)
                }
                if let action = state.lockedAction, state.fingerCount >= 3 {
                    drawWake(for: action, fingers: state.fingers, in: &context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func dotCount() -> Int {
        if reduceMotion { return 60 }
        switch state.fingerCount {
        case 4...: return 100
        case 3: return 120
        case 2: return 160
        default: return 220
        }
    }

    private func drawField(for finger: TouchAnimationFinger, in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let count = dotCount()
        let radius = min(size.width, size.height) * (state.isDragging ? 0.16 : 0.22)
        let speed = hypot(finger.velocity.width, finger.velocity.height)
        let wake = min(speed / 28.0, 18.0)
        let angle = atan2(finger.velocity.height, finger.velocity.width)
        let compress = state.isDragging ? 0.82 : (state.clickPulse > 0 ? 0.9 : 1.0)

        for index in 0..<count {
            let seed = Double((finger.id &* 7919) &+ index &* 104729)
            let hash = fract(sin(seed) * 43758.5453)
            let hash2 = fract(sin(seed * 1.7) * 23421.631)
            let hash3 = fract(sin(seed * 2.3) * 9981.123)
            let ring = pow(hash, 0.55)
            let orbit = reduceMotion ? 0 : time * (0.15 + hash3 * 0.25)
            let theta = hash2 * .pi * 2 + orbit
            let energy = pow(max(0, 1 - ring), 1.8)
            let distance = ring * radius * compress
            var offset = CGPoint(x: cos(theta) * distance, y: sin(theta) * distance)
            if wake > 0.5, reduceMotion == false {
                offset.x -= cos(angle) * wake * energy
                offset.y -= sin(angle) * wake * energy
            }
            if state.modeName == "scrolling", reduceMotion == false {
                let flow = state.gestureProgress.height != 0 ? state.gestureProgress.height : state.gestureProgress.width
                offset.y += sin(time * 6 + Double(index)) * min(abs(flow) * 0.02, 4) * energy
            }
            let point = CGPoint(x: finger.point.x + offset.x, y: finger.point.y + offset.y)
            let dotSize = 1.2 + energy * (state.isDragging ? 3.4 : 2.6)
            let opacity = 0.08 + energy * 0.72
            let color = Color(
                red: 0.35 + energy * 0.35,
                green: 0.70 + energy * 0.25,
                blue: 1.0
            ).opacity(opacity)
            context.fill(Path(ellipseIn: CGRect(x: point.x - dotSize / 2, y: point.y - dotSize / 2, width: dotSize, height: dotSize)), with: .color(color))
        }

        let core = max(6.0, 10.0 * compress)
        context.fill(
            Path(ellipseIn: CGRect(x: finger.point.x - core / 2, y: finger.point.y - core / 2, width: core, height: core)),
            with: .color(Color(red: 0.55, green: 0.82, blue: 1.0).opacity(state.isDragging ? 0.55 : 0.35))
        )
    }

    private func drawWake(for action: SystemAction, fingers: [TouchAnimationFinger], in context: inout GraphicsContext) {
        guard fingers.isEmpty == false else { return }
        let mid = CGPoint(
            x: fingers.map(\.point.x).reduce(0, +) / CGFloat(fingers.count),
            y: fingers.map(\.point.y).reduce(0, +) / CGFloat(fingers.count)
        )
        let vector: CGSize
        switch action {
        case .previousDesktop: vector = CGSize(width: -1, height: 0)
        case .nextDesktop: vector = CGSize(width: 1, height: 0)
        case .missionControl: vector = CGSize(width: 0, height: -1)
        case .appExpose: vector = CGSize(width: 0, height: 1)
        default: return
        }
        for step in 0..<8 {
            let t = CGFloat(step) / 8
            let point = CGPoint(x: mid.x + vector.width * t * 36, y: mid.y + vector.height * t * 36)
            let size = 18 - t * 12
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)),
                with: .color(Color.cyan.opacity(0.08 * (1 - t)))
            )
        }
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}
