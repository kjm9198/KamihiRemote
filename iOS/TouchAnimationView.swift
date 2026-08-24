import SwiftUI

struct TouchAnimationView: View {
    let state: TouchAnimationState
    @Namespace private var glassSpace
    @State private var clickScale: CGFloat = 1
    @State private var ripples: [Ripple] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: state.isFingerDown)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            canvas(at: t)
        }
        .onChange(of: state.clickPulse) { _, _ in
            pulse(scale: 0.85)
            ripples.append(Ripple(kind: .single))
        }
        .onChange(of: state.doubleClickPulse) { _, _ in
            pulse(scale: 0.8)
            ripples.append(Ripple(kind: .double))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func canvas(at time: TimeInterval) -> some View {
        let idle = !state.isFingerDown
        let floatX = idle && state.isConnected ? sin(time * 0.7) * 10 : 0
        let floatY = idle && state.isConnected ? cos(time * 0.55) * 8 : 0

        ZStack {
            GlassEffectContainer(spacing: 56) {
                if state.isConnected {
                    connectedOrbs(float: CGSize(width: floatX, height: floatY))
                } else {
                    searchingShards(at: time)
                }
            }
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: state.points)
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: state.isConnected)

            ForEach(ripples) { ripple in
                RippleView(ripple: ripple) {
                    ripples.removeAll { $0.id == ripple.id }
                }
                .position(orbOrigin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func connectedOrbs(float: CGSize) -> some View {
        if state.fingerCount >= 2, state.points.count >= 2 {
            ForEach(Array(state.points.prefix(2).enumerated()), id: \.offset) { index, point in
                orb(
                    id: index == 0 ? "primary" : "secondary",
                    size: 72,
                    stretch: 0.08,
                    pressed: true
                )
                .position(point)
            }
        } else {
            orb(
                id: "primary",
                size: state.isDragging ? 102 : 94,
                stretch: stretchAmount,
                pressed: state.isFingerDown || state.isDragging
            )
            .scaleEffect(clickScale)
            .rotationEffect(stretchAngle)
            .position(x: orbOrigin.x + float.width, y: orbOrigin.y + float.height)
        }
    }

    private func searchingShards(at time: TimeInterval) -> some View {
        let count = 6
        let radius: CGFloat = 46
        return ForEach(0..<count, id: \.self) { index in
            let angle = (Double(index) / Double(count)) * .pi * 2 + time * 0.35
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            Circle()
                .fill(.clear)
                .frame(width: 22, height: 22)
                .glassEffect(.regular, in: .circle)
                .glassEffectID("shard-\(index)", in: glassSpace)
                .position(point)
        }
    }

    private func orb(id: String, size: CGFloat, stretch: CGFloat, pressed: Bool) -> some View {
        let width = size * (1 + stretch)
        let height = size * (1 - stretch * 0.42)
        let material: Glass = pressed
            ? .regular.tint(.white.opacity(state.isDragging ? 0.42 : 0.18))
            : .regular

        return Capsule()
            .fill(.clear)
            .frame(width: width, height: height)
            .glassEffect(material, in: .capsule)
            .glassEffectID(id, in: glassSpace)
    }

    private var orbOrigin: CGPoint {
        if let point = state.points.first, state.isFingerDown {
            return point
        }
        return center
    }

    private var center: CGPoint {
        CGPoint(x: state.trackpadSize.width / 2, y: state.trackpadSize.height / 2)
    }

    private var stretchAmount: CGFloat {
        guard state.isFingerDown else { return 0 }
        let speed = hypot(state.velocity.width, state.velocity.height)
        return min(speed / 980, 0.42)
    }

    private var stretchAngle: Angle {
        Angle(radians: atan2(state.velocity.height, state.velocity.width))
    }

    private func pulse(scale: CGFloat) {
        clickScale = scale
        withAnimation(.spring(response: 0.28, dampingFraction: 0.42)) {
            clickScale = 1
        }
    }
}

private struct Ripple: Identifiable {
    enum Kind { case single, double }
    let id = UUID()
    let kind: Kind
    let created = Date()
}

private struct RippleView: View {
    let ripple: Ripple
    var onFinished: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ring(delay: 0)
            if ripple.kind == .double {
                ring(delay: 0.08)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                progress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: onFinished)
        }
        .allowsHitTesting(false)
    }

    private func ring(delay: Double) -> some View {
        Circle()
            .stroke(.white.opacity(0.28 * (1 - progress)), lineWidth: 2)
            .frame(width: 70 + progress * 90, height: 70 + progress * 90)
            .opacity(delay == 0 || progress > 0.05 ? 1 : 0)
    }
}
