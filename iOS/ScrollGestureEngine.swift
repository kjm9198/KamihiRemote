import CoreGraphics
import Foundation

struct GestureDebug: Equatable {
    var activeCount = 0
    var points: [CGPoint] = []
    var mode = "idle"
    var cumulativeX: CGFloat = 0
    var cumulativeY: CGFloat = 0
    var scrollIntent = "none"
}

final class ScrollGestureEngine {
    enum Intent: String {
        case unknown
        case scroll
        case pinch
    }

    var preferences = AppPreferences()
    private(set) var intent: Intent = .unknown

    private var startCentroid = CGPoint.zero
    private var lastCentroid = CGPoint.zero
    private var startSpan: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var vx = 0.0
    private var vy = 0.0
    private var pinchAccum = 0.0
    private var firedPinch = 0.0
    private var hasBegan = false
    private var momentumActive = false
    private var axisLock: Axis?

    private enum Axis { case horizontal, vertical }

    var isMomentumActive: Bool { momentumActive }

    func begin(points: [CGPoint], timestamp: TimeInterval) {
        intent = .unknown
        startCentroid = centroid(points)
        lastCentroid = startCentroid
        startSpan = span(points)
        lastTime = timestamp
        vx = 0
        vy = 0
        pinchAccum = 0
        firedPinch = 0
        hasBegan = false
        momentumActive = false
        axisLock = nil
    }

    func move(points: [CGPoint], timestamp: TimeInterval) -> [RemoteCommand] {
        momentumActive = false
        let center = centroid(points)
        let currentSpan = span(points)
        let dt = max(timestamp - lastTime, 0.001)
        let dx = Double(center.x - lastCentroid.x)
        let dy = Double(center.y - lastCentroid.y)
        let translation = hypot(center.x - startCentroid.x, center.y - startCentroid.y)
        let spanChange = abs(currentSpan - startSpan)

        if intent == .unknown {
            if spanChange > 18, spanChange > translation * 0.85 {
                intent = .pinch
            } else if translation > 10 {
                intent = .scroll
            }
        }

        lastTime = timestamp
        lastCentroid = center

        switch intent {
        case .unknown:
            return []
        case .pinch:
            pinchAccum = Double((currentSpan - startSpan) / max(startSpan, 1))
            return drainPinch()
        case .scroll:
            return scrollMoved(dx: dx, dy: dy, dt: dt)
        }
    }

    func end(isTap: Bool) -> [RemoteCommand] {
        if isTap {
            resetSoft()
            return []
        }
        if intent == .pinch {
            let leftover = drainPinch()
            resetSoft()
            return leftover
        }
        guard intent == .scroll else {
            resetSoft()
            return []
        }
        var commands: [RemoteCommand] = []
        if hasBegan {
            commands.append(.scroll(dx: 0, dy: 0, phase: .ended))
        }
        let speed = hypot(vx, vy)
        if preferences.effectiveScrollDecay > 0.2, speed > 420 {
            momentumActive = true
            commands.append(.scroll(dx: vx / 90, dy: vy / 90, phase: .momentumBegan))
        } else {
            momentumActive = false
            vx = 0
            vy = 0
        }
        intent = .unknown
        hasBegan = false
        return commands
    }

    func tickMomentum(dt: TimeInterval) -> [RemoteCommand] {
        guard momentumActive else { return [] }
        vx *= preferences.effectiveScrollDecay
        vy *= preferences.effectiveScrollDecay
        if hypot(vx, vy) < 28 {
            momentumActive = false
            vx = 0
            vy = 0
            return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
        }
        return [.scroll(dx: vx * dt, dy: vy * dt, phase: .momentumChanged)]
    }

    func cancel() -> [RemoteCommand] {
        var commands: [RemoteCommand] = []
        if hasBegan {
            commands.append(.scroll(dx: 0, dy: 0, phase: .ended))
        }
        if momentumActive {
            commands.append(.scroll(dx: 0, dy: 0, phase: .momentumEnded))
        }
        resetSoft()
        momentumActive = false
        return commands
    }

    private func resetSoft() {
        intent = .unknown
        hasBegan = false
        pinchAccum = 0
        firedPinch = 0
    }

    private func drainPinch() -> [RemoteCommand] {
        var commands: [RemoteCommand] = []
        let threshold = max(preferences.pinchThreshold, 0.06)
        while pinchAccum - firedPinch >= threshold {
            commands.append(.zoom(.in))
            firedPinch += threshold
        }
        while firedPinch - pinchAccum >= threshold {
            commands.append(.zoom(.out))
            firedPinch -= threshold
        }
        return commands
    }

    private func scrollMoved(dx: Double, dy: Double, dt: TimeInterval) -> [RemoteCommand] {
        let alpha = 0.35
        vx = vx * (1 - alpha) + (dx / dt) * alpha
        vy = vy * (1 - alpha) + (dy / dt) * alpha

        var outX = dx
        var outY = dy
        if abs(outX) > abs(outY) * 2.4 {
            axisLock = .horizontal
        } else if abs(outY) > abs(outX) * 2.4 {
            axisLock = .vertical
        }
        if axisLock == .horizontal { outY *= 0.12 }
        if axisLock == .vertical { outX *= 0.12 }

        let direction = preferences.naturalScrolling ? 1.0 : -1.0
        let gain = preferences.effectiveScrollGain
        outX *= gain * direction
        outY *= gain * direction
        guard hypot(outX, outY) > 0.2 else { return [] }

        if hasBegan == false {
            hasBegan = true
            return [
                .scroll(dx: 0, dy: 0, phase: .began),
                .scroll(dx: outX, dy: outY, phase: .changed)
            ]
        }
        return [.scroll(dx: outX, dy: outY, phase: .changed)]
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private func span(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        return hypot(points[0].x - points[1].x, points[0].y - points[1].y)
    }
}
