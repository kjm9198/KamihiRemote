import CoreGraphics
import Foundation
import UIKit

enum GestureMode: String, Equatable {
    case idle
    case pointer
    case tapCandidate
    case dragging
    case twoFingerCandidate
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
    var debug = GestureDebug()
}

final class GestureEngine {
    var preferences = AppPreferences() {
        didSet { scrollEngine.preferences = preferences }
    }
    var precisionActive = false
    var isConnected = false

    private(set) var mode: GestureMode = .idle
    private let scrollEngine = ScrollGestureEngine()
    private var fingers: [Int: CGPoint] = [:]
    private var lastCentroid: CGPoint?
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
    private var lastFingerIDs: Set<Int> = []

    private enum Axis { case horizontal, vertical }

    func handle(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, phase: UITouch.Phase, in size: CGSize) -> GestureOutput {
        switch phase {
        case .began:
            return began(changed: changed, active: active, timestamp: timestamp, size: size)
        case .moved, .stationary:
            return moved(changed: changed, active: active, timestamp: timestamp, size: size)
        case .ended:
            return ended(changed: changed, active: active, timestamp: timestamp, size: size)
        default:
            return cancel(size: size)
        }
    }

    /// Test-facing ingest that does not depend on a UIEvent.
    func ingest(samples: [FingerSample], timestamp: TimeInterval, phase: UITouch.Phase, in size: CGSize) -> GestureOutput {
        switch phase {
        case .began:
            var next = fingers
            for sample in samples { next[sample.id] = sample.point }
            let active = next.map { FingerSample(id: $0.key, point: $0.value) }
            return handle(changed: samples, active: active, timestamp: timestamp, phase: .began, in: size)
        case .moved:
            var next = fingers
            for sample in samples { next[sample.id] = sample.point }
            let active = next.map { FingerSample(id: $0.key, point: $0.value) }
            return handle(changed: samples, active: active, timestamp: timestamp, phase: .moved, in: size)
        case .ended:
            var next = fingers
            for sample in samples { next[sample.id] = nil }
            let active = next.map { FingerSample(id: $0.key, point: $0.value) }
            return handle(changed: samples, active: active, timestamp: timestamp, phase: .ended, in: size)
        default:
            return cancel(size: size)
        }
    }

    func tickMomentum(dt: TimeInterval, size: CGSize) -> GestureOutput {
        let commands = scrollEngine.tickMomentum(dt: dt)
        return GestureOutput(commands: commands, animation: makeAnimation(points: currentPoints(), size: size, down: !fingers.isEmpty, dragging: mouseIsDown), debug: makeDebug())
    }

    func cancel(size: CGSize) -> GestureOutput {
        longPressWork?.cancel()
        var commands = takeQueued()
        commands.append(contentsOf: scrollEngine.cancel())
        if mouseIsDown {
            commands.append(.mouseUp)
            mouseIsDown = false
        }
        resetTracking()
        mode = .idle
        return GestureOutput(commands: commands, animation: makeAnimation(points: [], size: size, down: false, dragging: false), debug: makeDebug())
    }

    private func began(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        Haptics.prepare()
        replaceActive(active)
        startTime = timestamp
        lastTimestamp = timestamp
        peakMovement = 0
        swipeAxis = nil
        lastDx = 0
        lastDy = 0
        let points = currentPoints()
        startCentroid = centroid(points)
        lastCentroid = startCentroid
        applyCount(points.count, timestamp: timestamp, points: points)
        lastFingerIDs = Set(fingers.keys)
        return GestureOutput(commands: takeQueued(), animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown), debug: makeDebug())
    }

    private func moved(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        replaceActive(active)
        let dt = max(timestamp - lastTimestamp, 0.0008)
        let points = currentPoints()
        let center = centroid(points)
        if let start = startCentroid {
            peakMovement = max(peakMovement, hypot(center.x - start.x, center.y - start.y))
        }

        var commands = takeQueued()
        let ids = Set(fingers.keys)
        if ids != lastFingerIDs {
            applyCount(points.count, timestamp: timestamp, points: points)
            lastFingerIDs = ids
            lastCentroid = center
            lastTimestamp = timestamp
            return GestureOutput(commands: commands, animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown), debug: makeDebug())
        }

        switch mode {
        case .tapCandidate, .pointer, .dragging:
            if peakMovement > 8 {
                cancelLongPress()
                if mode == .tapCandidate { mode = .pointer }
            }
            if mode != .tapCandidate, let previous = lastCentroid {
                let dx = Double(center.x - previous.x)
                let dy = Double(center.y - previous.y)
                if hypot(dx, dy) >= 0.45 {
                    let accelerated = accelerate(dx: dx, dy: dy, dt: min(max(dt, 1.0 / 240.0), 1.0 / 30.0))
                    commands.append(.move(dx: accelerated.dx, dy: accelerated.dy))
                }
            }
        case .twoFingerCandidate, .scrolling, .pinching:
            commands.append(contentsOf: scrollEngine.move(points: points, timestamp: timestamp))
            switch scrollEngine.intent {
            case .scroll: mode = .scrolling
            case .pinch: mode = .pinching
            case .unknown: mode = .twoFingerCandidate
            }
        case .threeFingerCandidate, .threeFingerSwipe:
            if let start = startCentroid {
                let dx = center.x - start.x
                let dy = center.y - start.y
                if hypot(dx, dy) > 36 {
                    mode = .threeFingerSwipe
                    lockAxis(dx: dx, dy: dy)
                }
            }
        case .fourFingerCandidate, .fourFingerSwipe:
            if let start = startCentroid {
                let dx = center.x - start.x
                let dy = center.y - start.y
                if hypot(dx, dy) > 36 {
                    mode = .fourFingerSwipe
                    lockAxis(dx: dx, dy: dy)
                }
            }
        case .idle:
            break
        }

        lastCentroid = center
        lastTimestamp = timestamp
        return GestureOutput(commands: commands, animation: makeAnimation(points: points, size: size, down: true, dragging: mouseIsDown || mode == .dragging), debug: makeDebug())
    }

    private func ended(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        replaceActive(active)
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
                    let isDouble = timestamp - lastClickTime < 0.3
                    lastClickTime = timestamp
                    clickPulse += 1
                    if isDouble {
                        commands.append(.doubleClick)
                        doubleClickPulse += 1
                    } else {
                        commands.append(.click)
                    }
                    Haptics.click()
                }
            case .twoFingerCandidate, .scrolling, .pinching:
                let scrollEnd = scrollEngine.end(isTap: isTap)
                if isTap, preferences.twoFingerSecondaryClick {
                    commands.append(.rightClick)
                    Haptics.rightClick()
                } else {
                    commands.append(contentsOf: scrollEnd)
                }
            default:
                if mouseIsDown {
                    commands.append(.mouseUp)
                    mouseIsDown = false
                }
                commands.append(contentsOf: scrollEngine.cancel())
            }
            resetTracking()
            mode = .idle
            return GestureOutput(commands: commands, animation: makeAnimation(points: [], size: size, down: false, dragging: false), debug: makeDebug())
        }

        applyCount(remaining, timestamp: timestamp, points: currentPoints())
        lastCentroid = centroid(currentPoints())
        lastFingerIDs = Set(fingers.keys)
        return GestureOutput(commands: commands, animation: makeAnimation(points: currentPoints(), size: size, down: true, dragging: mouseIsDown), debug: makeDebug())
    }

    private func applyCount(_ count: Int, timestamp: TimeInterval, points: [CGPoint]) {
        cancelLongPress()
        lastDx = 0
        lastDy = 0
        startCentroid = centroid(points)
        lastCentroid = startCentroid
        peakMovement = 0
        swipeAxis = nil
        switch count {
        case 1:
            mode = mouseIsDown ? .dragging : (mode == .idle ? .tapCandidate : .pointer)
            if mode == .tapCandidate { scheduleLongPress() }
            _ = scrollEngine.cancel()
        case 2:
            mode = .twoFingerCandidate
            scrollEngine.begin(points: points, timestamp: timestamp)
        case 3:
            mode = .threeFingerCandidate
            _ = scrollEngine.cancel()
        case 4...:
            mode = .fourFingerCandidate
            _ = scrollEngine.cancel()
        default:
            mode = .idle
            _ = scrollEngine.cancel()
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
            let slow = 1.0 - min(speed / 900.0, 1.0)
            let alpha = min(max(preferences.smoothing, 0.12) + slow * 0.22, 0.62)
            outX = outX * (1 - alpha) + lastDx * alpha
            outY = outY * (1 - alpha) + lastDy * alpha
        }
        let magnitude = hypot(outX, outY)
        let maxStep = 56.0 * max(preferences.effectiveSensitivity, 0.6)
        if magnitude > maxStep {
            outX *= maxStep / magnitude
            outY *= maxStep / magnitude
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

    private func replaceActive(_ active: [FingerSample]) {
        fingers.removeAll(keepingCapacity: true)
        for sample in active {
            fingers[sample.id] = sample.point
        }
    }

    private func resetTracking() {
        fingers.removeAll()
        lastCentroid = nil
        startCentroid = nil
        swipeAxis = nil
        lastDx = 0
        lastDy = 0
        peakMovement = 0
        lastFingerIDs.removeAll()
    }

    private func currentPoints() -> [CGPoint] {
        fingers.keys.sorted().compactMap { fingers[$0] }
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
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

    private func makeDebug() -> GestureDebug {
        let start = startCentroid ?? .zero
        let current = lastCentroid ?? start
        return GestureDebug(
            activeCount: fingers.count,
            points: currentPoints(),
            mode: mode.rawValue,
            cumulativeX: current.x - start.x,
            cumulativeY: current.y - start.y,
            scrollIntent: scrollEngine.intent.rawValue
        )
    }
}
