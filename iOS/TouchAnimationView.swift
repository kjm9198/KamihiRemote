import SwiftUI

struct TouchAnimationView: View {
    let state: TouchAnimationState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Namespace private var glassSpace
    @State private var clickScale: CGFloat = 1
    @State private var ripples: [Ripple] = []
    @State private var trail: [TrailDot] = []

    private var reduceMotion: Bool { systemReduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 20 : 1 / 60, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            canvas(at: t)
        }
        .onChange(of: state.clickPulse) { _, _ in
            pulse(scale: 0.82)
            ripples.append(Ripple(kind: .single, origin: orbOrigin))
        }
        .onChange(of: state.doubleClickPulse) { _, _ in
            pulse(scale: 0.76)
            ripples.append(Ripple(kind: .double, origin: orbOrigin))
        }
        .onChange(of: state.points) { _, points in
            guard let point = points.first, state.isFingerDown, reduceMotion == false else { return }
            trail.append(TrailDot(point: point, energy: hypot(state.velocity.width, state.velocity.height)))
            if trail.count > 18 { trail.removeFirst(trail.count - 18) }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func canvas(at time: TimeInterval) -> some View {
        let breathe = reduceMotion ? 0 : sin(time * 1.15) * 0.5 + 0.5
        ZStack {
            ambientField(at: time, breathe: breathe)
            ForEach(trail) { dot in
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 10, height: 10)
                    .blur(radius: 6)
                    .position(dot.point)
            }
            GlassEffectContainer(spacing: 72) {
                if state.isConnected {
                    connectedOrbs(at: time)
                } else {
                    searchingConstellation(at: time)
                }
            }
            .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.72), value: state.points)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: state.isConnected)

            ForEach(ripples) { ripple in
                RippleView(ripple: ripple) {
                    ripples.removeAll { $0.id == ripple.id }
                }
                .position(ripple.origin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ambientField(at time: TimeInterval, breathe: Double) -> some View {
        let connected = state.isConnected
        let radius = min(state.trackpadSize.width, state.trackpadSize.height) * (connected ? 0.42 : 0.28)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.35, green: 0.55, blue: 0.95).opacity(connected ? 0.22 + breathe * 0.10 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .blur(radius: 18)
            if connected && reduceMotion == false {
                Circle()
                    .stroke(.white.opacity(0.08 + breathe * 0.06), lineWidth: 1.2)
                    .frame(width: 120 + breathe * 18, height: 120 + breathe * 18)
                    .position(center)
            }
        }
    }

    @ViewBuilder
    private func connectedOrbs(at time: TimeInterval) -> some View {
        let points = Array(state.points.prefix(4))
        if state.isFingerDown, points.isEmpty == false {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                orb(
                    id: "finger-\(index)",
                    size: index == 0 ? (state.isDragging ? 108 : 92) : 64,
                    stretch: index == 0 ? stretchAmount : 0.04,
                    pressed: true
                )
                .scaleEffect(index == 0 ? clickScale : 1)
                .rotationEffect(index == 0 ? stretchAngle : .zero)
                .position(point)
            }
        } else {
            let float = reduceMotion ? 0.0 : sin(time * 0.65) * 10
            orb(
                id: "idle",
                size: 88 + (state.isPrecision ? -10 : 8),
                stretch: 0.06,
                pressed: false
            )
            .scaleEffect(clickScale)
            .position(x: center.x, y: center.y + float)
        }
    }

    private func searchingConstellation(at time: TimeInterval) -> some View {
        let count = 8
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let ring = index < 4 ? 42.0 : 68.0
                let speed = index < 4 ? 0.55 : -0.32
                let angle = (Double(index % 4) / 4.0) * .pi * 2 + time * speed
                Circle()
                    .fill(.clear)
                    .frame(width: index < 4 ? 20 : 14, height: index < 4 ? 20 : 14)
                    .glassEffect(.regular, in: .circle)
                    .glassEffectID("search-\(index)", in: glassSpace)
                    .position(
                        x: center.x + CGFloat(cos(angle)) * ring,
                        y: center.y + CGFloat(sin(angle)) * ring
                    )
            }
            orb(id: "search-core", size: 36, stretch: 0.04, pressed: false)
                .position(center)
        }
    }

    private func orb(id: String, size: CGFloat, stretch: CGFloat, pressed: Bool) -> some View {
        let width = size * (1 + stretch)
        let height = size * (1 - stretch * 0.46)
        let material: Glass = pressed
            ? .regular.tint(.white.opacity(state.isDragging ? 0.46 : 0.22))
            : .regular.tint(Color(red: 0.55, green: 0.72, blue: 1.0).opacity(0.16))
        return Capsule()
            .fill(.clear)
            .frame(width: width, height: height)
            .glassEffect(material, in: .capsule)
            .glassEffectID(id, in: glassSpace)
            .shadow(color: .white.opacity(pressed ? 0.18 : 0.08), radius: pressed ? 18 : 10)
    }

    private var orbOrigin: CGPoint {
        if let point = state.points.first, state.isFingerDown { return point }
        return center
    }

    private var center: CGPoint {
        CGPoint(x: state.trackpadSize.width / 2, y: state.trackpadSize.height / 2)
    }

    private var stretchAmount: CGFloat {
        guard state.isFingerDown else { return 0.04 }
        let speed = hypot(state.velocity.width, state.velocity.height)
        return min(speed / 860, 0.48)
    }

    private var stretchAngle: Angle {
        Angle(radians: atan2(state.velocity.height, state.velocity.width))
    }

    private func pulse(scale: CGFloat) {
        clickScale = scale
        withAnimation(.spring(response: 0.32, dampingFraction: 0.38)) {
            clickScale = 1
        }
    }
}

private struct TrailDot: Identifiable {
    let id = UUID()
    let point: CGPoint
    let energy: CGFloat
}

private struct Ripple: Identifiable {
    enum Kind { case single, double }
    let id = UUID()
    let kind: Kind
    let origin: CGPoint
}

private struct RippleView: View {
    let ripple: Ripple
    var onFinished: () -> Void
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ring(delay: 0, width: 2.4)
            ring(delay: 0.06, width: 1.2)
            if ripple.kind == .double {
                ring(delay: 0.12, width: 1.6)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.72)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.76, execute: onFinished)
        }
        .allowsHitTesting(false)
    }

    private func ring(delay: Double, width: CGFloat) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [.white.opacity(0.55), .cyan.opacity(0.25), .white.opacity(0.05)],
                    center: .center
                ),
                lineWidth: width
            )
            .frame(width: 54 + progress * 140, height: 54 + progress * 140)
            .opacity((1 - progress) * (delay == 0 || progress > 0.04 ? 1 : 0))
            .scaleEffect(0.92 + progress * 0.12)
    }
}
