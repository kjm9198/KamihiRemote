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
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 30 : 1 / 60, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            canvas(at: t)
        }
        .onChange(of: state.clickPulse) { _, _ in
            pulse(scale: 0.82)
            ripples.append(Ripple(kind: .single, origin: orbOrigin))
        }
        .onChange(of: state.doubleClickPulse) { _, _ in
            pulse(scale: 0.74)
            ripples.append(Ripple(kind: .double, origin: orbOrigin))
        }
        .onChange(of: state.points) { _, points in
            guard state.isFingerDown, reduceMotion == false else { return }
            for point in points.prefix(4) {
                trail.append(TrailDot(point: point, energy: hypot(state.velocity.width, state.velocity.height)))
            }
            if trail.count > 24 { trail.removeFirst(trail.count - 24) }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func canvas(at time: TimeInterval) -> some View {
        let breathe = reduceMotion ? 0 : sin(time * 1.2) * 0.5 + 0.5
        ZStack {
            ambientField(at: time, breathe: breathe)

            if reduceMotion == false {
                ForEach(trail) { dot in
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 8, height: 8)
                        .blur(radius: 5)
                        .position(dot.point)
                }
            }

            // Discrete glass bubbles — no GlassEffectContainer morphing, which pulls orbs off-finger.
            if state.isFingerDown {
                connectedOrbs(at: time)
            }

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
        // Idle: very subtle presence only — never compete with finger glass.
        let connected = state.isConnected
        let radius = min(state.trackpadSize.width, state.trackpadSize.height) * 0.28
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.35, green: 0.55, blue: 0.95).opacity(connected ? 0.06 + breathe * 0.03 : 0.03),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .blur(radius: 24)
            .opacity(state.isFingerDown ? 0.35 : 1)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func connectedOrbs(at time: TimeInterval) -> some View {
        let fingers = Array(state.fingers.prefix(4))
        if fingers.isEmpty == false {
            // Two-finger interactive glass metaball bridge
            if fingers.count == 2 {
                glassBridge(from: fingers[0].point, to: fingers[1].point, isScrolling: state.modeName == "scrolling", isPinching: state.modeName == "pinching")
            }

            // Three-finger group aura / directional shear feedback
            if fingers.count == 3 {
                threeFingerGroupAura(fingers: fingers)
            }

            // Four-finger group aura
            if fingers.count >= 4 {
                fourFingerGroupAura(fingers: fingers)
            }

            // Individual stable contact orbs — geometric center == finger tip. No rotation lag.
            ForEach(fingers) { finger in
                let count = fingers.count
                orb(
                    id: "finger-\(finger.id)",
                    size: orbSize(count: count),
                    stretch: count == 1 ? min(stretchAmount, 0.18) : 0.02,
                    pressed: true
                )
                .scaleEffect(count == 1 ? clickScale : 1)
                // Only slight stretch for one finger; never rotate multi-finger orbs off-center.
                .rotationEffect(count == 1 ? stretchAngle : .zero)
                .position(finger.point)
                .transaction { $0.animation = nil }
            }
        }
    }

    private func glassBridge(from a: CGPoint, to b: CGPoint, isScrolling: Bool, isPinching: Bool) -> some View {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let length = hypot(b.x - a.x, b.y - a.y)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let tension = max(0.2, 1.0 - min(length / 280.0, 0.8))

        return ZStack {
            Capsule()
                .fill(.clear)
                .frame(width: max(length - 28, 14), height: isScrolling ? 24 : (isPinching ? 28 : 18))
                .glassEffect(.regular.tint(.white.opacity(0.12 * tension)), in: .capsule)
                .rotationEffect(.radians(angle))
                .position(mid)
                .opacity(reduceMotion ? 0.4 : 0.75 * tension)

            if isScrolling && reduceMotion == false {
                // Subtle directional flow streak during scrolling
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 36)
                    .position(mid)
                    .blur(radius: 3)
            }
        }
        .allowsHitTesting(false)
    }

    private func threeFingerGroupAura(fingers: [TouchAnimationFinger]) -> some View {
        let pts = fingers.map(\.point)
        let midX = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
        let midY = pts.reduce(0) { $0 + $1.y } / CGFloat(pts.count)
        let shiftX = state.gestureProgress.width * 0.3
        let shiftY = state.gestureProgress.height * 0.3

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.cyan.opacity(state.modeName == "threeFingerSwipe" ? 0.28 : 0.12),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 90
                )
            )
            .frame(width: 180, height: 180)
            .position(x: midX + shiftX, y: midY + shiftY)
            .blur(radius: 12)
            .allowsHitTesting(false)
    }

    private func fourFingerGroupAura(fingers: [TouchAnimationFinger]) -> some View {
        let pts = fingers.map(\.point)
        let midX = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
        let midY = pts.reduce(0) { $0 + $1.y } / CGFloat(pts.count)

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.45, green: 0.65, blue: 1.0).opacity(0.25),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 15,
                    endRadius: 110
                )
            )
            .frame(width: 220, height: 220)
            .position(x: midX, y: midY)
            .blur(radius: 16)
            .allowsHitTesting(false)
    }

    private func orbSize(count: Int) -> CGFloat {
        if count == 1 { return state.isDragging ? 104 : 88 }
        if count == 2 { return 68 }
        if count == 3 { return 56 }
        return 48
    }

    private var groupStretch: CGFloat {
        guard state.fingerCount >= 3, state.isFingerDown else { return 0.04 }
        return min(hypot(state.gestureProgress.width, state.gestureProgress.height) / 400, 0.25)
    }

    private var groupRotation: Angle {
        guard state.fingerCount >= 3 else {
            return state.fingerCount == 1 ? stretchAngle : .zero
        }
        return Angle(radians: atan2(state.gestureProgress.height, state.gestureProgress.width))
    }

    private func orb(id: String, size: CGFloat, stretch: CGFloat, pressed: Bool) -> some View {
        let width = size * (1 + stretch)
        let height = size * (1 - stretch * 0.45)
        let material: Glass = pressed
            ? .regular.tint(.white.opacity(state.isDragging ? 0.44 : 0.28))
            : .regular.tint(Color(red: 0.55, green: 0.72, blue: 1.0).opacity(0.18))
        // Prefer Circle for multi-touch so visual center == position center.
        return Group {
            if stretch < 0.05 {
                Circle()
                    .fill(.clear)
                    .frame(width: size, height: size)
                    .glassEffect(material, in: .circle)
            } else {
                Capsule()
                    .fill(.clear)
                    .frame(width: width, height: height)
                    .glassEffect(material, in: .capsule)
            }
        }
        .shadow(color: .white.opacity(pressed ? 0.18 : 0.08), radius: pressed ? 14 : 8)
        .allowsHitTesting(false)
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
        return min(speed / 800, 0.45)
    }

    private var stretchAngle: Angle {
        Angle(radians: atan2(state.velocity.height, state.velocity.width))
    }

    private func pulse(scale: CGFloat) {
        clickScale = scale
        withAnimation(.spring(response: 0.28, dampingFraction: 0.4)) {
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
            ring(delay: 0, width: 2.2)
            ring(delay: 0.05, width: 1.2)
            if ripple.kind == .double {
                ring(delay: 0.10, width: 1.5)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.68)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: onFinished)
        }
        .allowsHitTesting(false)
    }

    private func ring(delay: Double, width: CGFloat) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [.white.opacity(0.50), .cyan.opacity(0.25), .white.opacity(0.05)],
                    center: .center
                ),
                lineWidth: width
            )
            .frame(width: 50 + progress * 130, height: 50 + progress * 130)
            .opacity((1 - progress) * (delay == 0 || progress > 0.04 ? 1 : 0))
            .scaleEffect(0.92 + progress * 0.12)
    }
}
