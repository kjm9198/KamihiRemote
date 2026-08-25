import CoreGraphics
import Foundation

struct GestureDebug: Equatable {
    var activeCount = 0
    var points: [CGPoint] = []
    var mode = "idle"
    var startCentroid = CGPoint.zero
    var currentCentroid = CGPoint.zero
    var cumulativeX: CGFloat = 0
    var cumulativeY: CGFloat = 0
    var axis: String = "none"
    var direction: String = "none"
    var isLocked: Bool = false
    var lastCommand: String = "none"
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

    private struct VelocitySample {
        var dx: Double
        var dy: Double
        var dt: TimeInterval
        var timestamp: TimeInterval
    }
    private var velocityHistory: [VelocitySample] = []

    private enum Axis { case horizontal, vertical }

    var isMomentumActive: Bool { momentumActive }

    func begin(points: [CGPoint], timestamp: TimeInterval) -> [RemoteCommand] {
        var cancelCommands: [RemoteCommand] = []
        if momentumActive {
            momentumActive = false
            cancelCommands.append(.scroll(dx: 0, dy: 0, phase: .momentumEnded))
        }
        intent = .unknown
        startCentroid = centroid(points)
        lastCentroid = startCentroid
        startSpan = span(points)
        lastTime = timestamp
        vx = 0
        vy = 0
        velocityHistory.removeAll()
        pinchAccum = 0
        firedPinch = 0
        hasBegan = false
        axisLock = nil
        return cancelCommands
    }

    func move(points: [CGPoint], timestamp: TimeInterval) -> [RemoteCommand] {
        if momentumActive {
            momentumActive = false
        }
        let center = centroid(points)
        let dt = max(timestamp - lastTime, 0.0008)
        let dx = Double(center.x - lastCentroid.x)
        let dy = Double(center.y - lastCentroid.y)
        let translation = hypot(center.x - startCentroid.x, center.y - startCentroid.y)
        let currentSpan = span(points)
        let spanDelta = currentSpan - startSpan

        if intent == .unknown {
            if preferences.pinchEnabled && abs(spanDelta) > 12 && abs(spanDelta) > translation * 1.15 {
                intent = .pinch
            } else if translation > 2 {
                intent = .scroll
            }
        }

        lastTime = timestamp
        lastCentroid = center

        switch intent {
        case .unknown:
            return []
        case .scroll:
            return scrollMoved(dx: dx, dy: dy, dt: dt, timestamp: timestamp)
        case .pinch:
            guard preferences.pinchEnabled else { return [] }
            pinchAccum = Double((currentSpan - startSpan) / max(startSpan, 1.0))
            return drainPinch()
        }
    }

    func end(isTap: Bool) -> [RemoteCommand] {
        if isTap {
            resetSoft()
            return []
        }
        guard intent == .scroll || intent == .pinch else {
            resetSoft()
            return []
        }
        var commands: [RemoteCommand] = []
        if hasBegan {
            commands.append(.scroll(dx: 0, dy: 0, phase: .ended))
        }

        // Estimate release velocity from rolling weighted history
        let releaseVelocity = estimateReleaseVelocity()
        vx = releaseVelocity.vx
        vy = releaseVelocity.vy
        let speed = hypot(vx, vy)

        if preferences.scrollFeel == .macLike, speed > 60 {
            momentumActive = true
            commands.append(.scroll(dx: vx / 60, dy: vy / 60, phase: .momentumBegan))
        } else {
            momentumActive = false
            vx = 0
            vy = 0
        }
        intent = .unknown
        hasBegan = false
        velocityHistory.removeAll()
        return commands
    }

    func tickMomentum(dt: TimeInterval) -> [RemoteCommand] {
        guard momentumActive else { return [] }
        // Continuous time-based exponential decay: v(t+dt) = v(t) * exp(-lambda * dt)
        // For Mac-like feel, lambda is ~3.2 s^-1
        let lambda: Double
        switch preferences.scrollFeel {
        case .macLike:
            lambda = 1.8
        case .direct:
            momentumActive = false
            vx = 0
            vy = 0
            return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
        case .custom:
            lambda = max(1.0, (1.0 - preferences.scrollMomentum) * 35.0)
        }

        let decayFactor = exp(-lambda * dt)
        vx *= decayFactor
        vy *= decayFactor

        let minSpeed = 6.0
        if hypot(vx, vy) < minSpeed {
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
        velocityHistory.removeAll()
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
        let threshold = max(preferences.pinchThreshold, 0.05)
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

    private func scrollMoved(dx: Double, dy: Double, dt: TimeInterval, timestamp: TimeInterval) -> [RemoteCommand] {
        velocityHistory.append(VelocitySample(dx: dx, dy: dy, dt: dt, timestamp: timestamp))
        if velocityHistory.count > 16 {
            velocityHistory.removeFirst(velocityHistory.count - 16)
        }

        var outX = dx
        var outY = dy

        // Axis assistance: gently damp the minor axis if user is scrolling mostly along one axis
        if abs(outX) > abs(outY) * 2.2 {
            axisLock = .horizontal
        } else if abs(outY) > abs(outX) * 2.2 {
            axisLock = .vertical
        }
        if axisLock == .horizontal { outY *= 0.15 }
        if axisLock == .vertical { outX *= 0.15 }

        let direction = preferences.naturalScrolling ? 1.0 : -1.0
        let gain = preferences.effectiveScrollGain
        outX *= gain * direction
        outY *= gain * direction

        guard hypot(outX, outY) > 0.1 else { return [] }

        if hasBegan == false {
            hasBegan = true
            return [
                .scroll(dx: 0, dy: 0, phase: .began),
                .scroll(dx: outX, dy: outY, phase: .changed)
            ]
        }
        return [.scroll(dx: outX, dy: outY, phase: .changed)]
    }

    private func estimateReleaseVelocity() -> (vx: Double, vy: Double) {
        guard let latestTime = velocityHistory.last?.timestamp else { return (0, 0) }
        // Look at samples from the last 80ms
        let recent = velocityHistory.filter { latestTime - $0.timestamp <= 0.08 }
        guard !recent.isEmpty else { return (0, 0) }

        var totalWeight = 0.0
        var weightedVx = 0.0
        var weightedVy = 0.0

        let direction = preferences.naturalScrolling ? 1.0 : -1.0
        let gain = preferences.effectiveScrollGain

        for sample in recent {
            let age = latestTime - sample.timestamp
            let weight = exp(-age / 0.03) // higher weight for newest samples
            let sampleVx = (sample.dx / max(sample.dt, 0.001)) * gain * direction
            let sampleVy = (sample.dy / max(sample.dt, 0.001)) * gain * direction
            weightedVx += sampleVx * weight
            weightedVy += sampleVy * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return (0, 0) }
        return (weightedVx / totalWeight, weightedVy / totalWeight)
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
