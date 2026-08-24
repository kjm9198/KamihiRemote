import CoreGraphics
import Foundation
import UIKit

enum GestureMode: String, Equatable {
    case idle
    case pointer
    case tapCandidate
    case dragging
    case scrolling
    case pinching
    case threeFingerCandidate
    case threeFingerSwipe
    case fourFingerCandidate
    case fourFingerSwipe
}

struct FingerSample: Equatable {
    var id: Int
    var point: CGPoint
}

struct GestureOutput {
    var commands: [RemoteCommand] = []
    var animation = TouchAnimationState.idle
}

final class GestureEngine {
    var preferences = AppPreferences()
    var precisionActive = false
    var isConnected = false

    private(set) var mode: GestureMode = .idle
    private var fingers: [Int: CGPoint] = [:]
    private var lastCentroid: CGPoint?
    private var lastPinchDistance: CGFloat?
    private var lastTimestamp: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private var startCentroid: CGPoint?
    private var peakMovement: CGFloat = 0
    private var swipeAxis: Axis?
    private var lastClickTime: TimeInterval = 0
    private var mouseIsDown = false
    private var longPressWork: DispatchWorkItem?
    private var queued: [RemoteCommand] = []
    private var lastDx = 0.0
    private var lastDy = 0.0
    private var clickPulse = 0
    private var doubleClickPulse = 0

    private enum Axis { case horizontal, vertical }

    func handle(samples: [FingerSample], timestamp: TimeInterval, phase: UITouch.Phase, in size: CGSize) -> GestureOutput {
        switch phase {
        case .began:
            return began(samples, timestamp: timestamp, size: size)
        case .moved:
            return moved(samples, timestamp: timestamp, size: size)
        case .ended:
            return ended(samples, timestamp: timestamp, size: size)
        default:
            return cancel(size: size)
        }
    }

    func cancel(size: CGSize) -> GestureOutput {
        longPressWork?.cancel()
        var commands = takeQueued()
        if mouseIsDown {
            commands.append(.mouseUp)
            mouseIsDown = false
        }
        resetTracking()
        mode = .idle
        return GestureOutput(commands: commands, animation: makeAnimation(points: [], size: size, down: false, dragging: false))
    }

    private func began(_ samples: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        Haptics.prepare()
        merge(samples)
        startTime = timestamp
        lastTimestamp = timestamp
        peakMovement = 0
        swipeAxis = nil
        lastPinchDistance = nil
        lastDx = 0
        lastDy = 0
        let points = currentPoints()
        startCentroid = centroid(points)
        lastCentroid = startCentroid

        switch fingers.count {
        case 1:
            mode = .tapCandidate
            scheduleLongPress()
        case 2:
            cancelLongPress()
            mode = .scrolling
            lastPinchDistance = span(points)
        case 3:
            cancelLongPress()
            mode = .threeFingerCandidate
        default:
            cancelLongPress()
            mode = fingers.count >= 4 ? .fourFingerCandidate : .idle
        }
        return GestureOutput(commands: takeQueued(), animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown))
    }

    private func moved(_ samples: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        merge(samples)
        let dt = max(timestamp - lastTimestamp, 0.0008)
        let points = currentPoints()
        let center = centroid(points)
        if let start = startCentroid {
            peakMovement = max(peakMovement, hypot(center.x - start.x, center.y - start.y))
        }

        var commands = takeQueued()
        if fingers.count != expectedCount(for: mode) {
            transition(toCount: fingers.count)
            lastCentroid = center
            lastPinchDistance = fingers.count >= 2 ? span(points) : nil
            lastTimestamp = timestamp
            return GestureOutput(commands: commands, animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown))
        }

        switch mode {
        case .tapCandidate, .pointer, .dragging:
            if peakMovement > 10 {
                cancelLongPress()
                if mode == .tapCandidate { mode = .pointer }
            }
            if let previous = lastCentroid {
                let dx = Double(center.x - previous.x)
                let dy = Double(center.y - previous.y)
                let accelerated = accelerate(dx: dx, dy: dy, dt: dt)
                commands.append(.move(dx: accelerated.dx, dy: accelerated.dy))
            }
        case .scrolling:
            if let previous = lastCentroid {
                let dx = Double(center.x - previous.x)
                let dy = Double(center.y - previous.y)
                if hypot(dx, dy) > 0.35 {
                    let direction = preferences.naturalScrolling ? 1.0 : -1.0
                    let speed = preferences.scrollSpeed
                    commands.append(.scroll(dx: dx * speed * direction, dy: dy * speed * direction))
                }
            }
            if let previousSpan = lastPinchDistance {
                let currentSpan = span(points)
                let delta = Double((currentSpan - previousSpan) / max(previousSpan, 1))
                if abs(delta) > 0.012 {
                    commands.append(.pinch(delta: delta))
                    mode = .pinching
                }
            }
            lastPinchDistance = span(points)
        case .pinching:
            if let previousSpan = lastPinchDistance {
                let currentSpan = span(points)
                let delta = Double((currentSpan - previousSpan) / max(previousSpan, 1))
                if abs(delta) > 0.002 {
                    commands.append(.pinch(delta: delta))
                }
            }
            lastPinchDistance = span(points)
        case .threeFingerCandidate, .threeFingerSwipe:
            if let previous = lastCentroid {
                let dx = center.x - previous.x
                let dy = center.y - previous.y
                if hypot(dx, dy) > 18 {
                    mode = .threeFingerSwipe
                    lockAxis(dx: dx, dy: dy)
                }
            }
        case .fourFingerCandidate, .fourFingerSwipe:
            if let previous = lastCentroid {
                let dx = center.x - previous.x
                let dy = center.y - previous.y
                if hypot(dx, dy) > 18 {
                    mode = .fourFingerSwipe
                    lockAxis(dx: dx, dy: dy)
                }
            }
        case .idle:
            break
        }

        lastCentroid = center
        lastTimestamp = timestamp
        return GestureOutput(commands: commands, animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown || mode == .dragging))
    }

    private func ended(_ samples: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        for sample in samples { fingers[sample.id] = nil }
        var commands = takeQueued()
        let remaining = fingers.count
        let duration = timestamp - startTime
        let isTap = peakMovement < 12 && duration < 0.32

        if remaining == 0 {
            cancelLongPress()
            switch mode {
            case .dragging:
                commands.append(.mouseUp)
                mouseIsDown = false
                Haptics.dragEnd()
            case .threeFingerSwipe:
                if let action = threeFingerAction(), action != .none {
                    commands.append(.system(action))
                    Haptics.gesture()
                }
            case .fourFingerSwipe:
                if let action = fourFingerAction(), action != .none {
                    commands.append(.system(action))
                    Haptics.gesture()
                }
            case .tapCandidate, .pointer:
                if mouseIsDown {
                    commands.append(.mouseUp)
                    mouseIsDown = false
                } else if isTap, preferences.tapToClick {
                    commands.append(.click)
                    Haptics.click()
                    let isDouble = timestamp - lastClickTime < 0.3
                    lastClickTime = timestamp
                    clickPulse += 1
                    if isDouble { doubleClickPulse += 1 }
                }
            case .scrolling:
                if isTap, preferences.twoFingerSecondaryClick {
                    commands.append(.rightClick)
                    Haptics.rightClick()
                }
            default:
                if mouseIsDown {
                    commands.append(.mouseUp)
                    mouseIsDown = false
                }
            }
            resetTracking()
            mode = .idle
            return GestureOutput(commands: commands, animation: makeAnimation(points: [], size: size, down: false, dragging: false))
        }

        transition(toCount: remaining)
        lastCentroid = centroid(currentPoints())
        lastPinchDistance = remaining >= 2 ? span(currentPoints()) : nil
        return GestureOutput(commands: commands, animation: makeAnimation(points: currentPoints(), size: size, down: true, dragging: mouseIsDown))
    }

    private func transition(toCount count: Int) {
        cancelLongPress()
        lastDx = 0
        lastDy = 0
        lastCentroid = nil
        switch count {
        case 1:
            mode = mouseIsDown ? .dragging : .pointer
        case 2:
            mode = .scrolling
        case 3:
            mode = .threeFingerCandidate
        case 4...:
            mode = .fourFingerCandidate
        default:
            mode = .idle
        }
    }

    private func expectedCount(for mode: GestureMode) -> Int {
        switch mode {
        case .idle: return 0
        case .pointer, .tapCandidate, .dragging: return 1
        case .scrolling, .pinching: return 2
        case .threeFingerCandidate, .threeFingerSwipe: return 3
        case .fourFingerCandidate, .fourFingerSwipe: return 4
        }
    }

    private func accelerate(dx: Double, dy: Double, dt: Double) -> (dx: Double, dy: Double) {
        let speed = hypot(dx, dy) / dt
        let gain = 1.0 + min(speed / 1400.0, 2.4) * preferences.effectiveAcceleration
        var outX = dx * preferences.effectiveSensitivity * gain
        var outY = dy * preferences.effectiveSensitivity * gain
        if precisionActive {
            outX *= preferences.precisionGain
            outY *= preferences.precisionGain
        }
        if preferences.smoothingEnabled {
            let alpha = min(max(preferences.smoothing, 0), 0.6)
            outX = outX * (1 - alpha) + lastDx * alpha
            outY = outY * (1 - alpha) + lastDy * alpha
        }
        lastDx = outX
        lastDy = outY
        return (outX, outY)
    }

    private func scheduleLongPress() {
        cancelLongPress()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.peakMovement < 10, !self.mouseIsDown else { return }
            self.mouseIsDown = true
            self.mode = .dragging
            self.queued.append(.mouseDown)
            Haptics.mouseDown()
        }
        longPressWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: work)
    }

    private func cancelLongPress() {
        longPressWork?.cancel()
        longPressWork = nil
    }

    private func takeQueued() -> [RemoteCommand] {
        let commands = queued
        queued.removeAll()
        return commands
    }

    private func threeFingerAction() -> SystemAction? {
        guard let axis = swipeAxis, let start = startCentroid, let current = lastCentroid else { return nil }
        if axis == .horizontal {
            return current.x > start.x ? preferences.bindings.threeFingerRight : preferences.bindings.threeFingerLeft
        }
        return current.y > start.y ? preferences.bindings.threeFingerDown : preferences.bindings.threeFingerUp
    }

    private func fourFingerAction() -> SystemAction? {
        guard let axis = swipeAxis, let start = startCentroid, let current = lastCentroid else { return nil }
        if axis == .horizontal {
            return current.x > start.x ? preferences.bindings.fourFingerRight : preferences.bindings.fourFingerLeft
        }
        return current.y > start.y ? preferences.bindings.fourFingerDown : preferences.bindings.fourFingerUp
    }

    private func lockAxis(dx: CGFloat, dy: CGFloat) {
        if swipeAxis == nil {
            swipeAxis = abs(dx) > abs(dy) ? .horizontal : .vertical
        }
    }

    private func merge(_ samples: [FingerSample]) {
        for sample in samples {
            fingers[sample.id] = sample.point
        }
    }

    private func resetTracking() {
        fingers.removeAll()
        lastCentroid = nil
        lastPinchDistance = nil
        startCentroid = nil
        swipeAxis = nil
        lastDx = 0
        lastDy = 0
        peakMovement = 0
    }

    private func currentPoints() -> [CGPoint] {
        Array(fingers.values)
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

    private func makeAnimation(points: [CGPoint], size: CGSize, down: Bool, dragging: Bool) -> TouchAnimationState {
        TouchAnimationState(
            isConnected: isConnected,
            fingerCount: points.count,
            points: points,
            velocity: CGSize(width: lastDx, height: lastDy),
            isFingerDown: down,
            isDragging: dragging,
            clickPulse: clickPulse,
            doubleClickPulse: doubleClickPulse,
            trackpadSize: size,
            modeName: mode.rawValue,
            isPrecision: precisionActive
        )
    }
}
