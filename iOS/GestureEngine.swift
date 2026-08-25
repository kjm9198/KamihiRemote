import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GestureMode: String, Equatable {
    case idle
    case pointer
    case tapCandidate
    case dragPending
    case dragging
    case twoFingerCandidate
    case scrolling
    case pinching
    case threeFingerCandidate
    case threeFingerSwipe
    case fourFingerCandidate
    case fourFingerSwipe
    case cancelled
}

struct FingerSample: Equatable {
    var id: Int
    var point: CGPoint
    var phase: UITouch.Phase = .moved
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
    private var maxClusterCount: Int = 0
    private var swipeAxis: Axis?
    private var committedAction: SystemAction?
    private var didEmitSwipe = false
    private var lastClickTime: TimeInterval = 0
    private var mouseIsDown = false
    private var longPressWork: DispatchWorkItem?
    private var queued: [RemoteCommand] = []
    private var lastDx = 0.0
    private var lastDy = 0.0
    private var clickPulse = 0
    private var doubleClickPulse = 0
    private var lastFingerIDs: Set<Int> = []
    private var previousFingers: [Int: CGPoint] = [:]

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

    /// Test-facing ingest that simulates touches and updates active fingers.
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
        return GestureOutput(
            commands: commands,
            animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: !fingers.isEmpty, dragging: mouseIsDown),
            debug: makeDebug()
        )
    }

    func cancel(size: CGSize) -> GestureOutput {
        longPressWork?.cancel()
        var commands = takeQueued()
        // If a multi-finger swipe locked but never emitted (rare), still emit on cancel.
        if didEmitSwipe == false {
            if mode == .threeFingerSwipe, let action = committedAction ?? threeFingerAction(), action != .none {
                commands.append(.system(action))
                didEmitSwipe = true
            } else if mode == .fourFingerSwipe, let action = committedAction ?? fourFingerAction(), action != .none {
                commands.append(.system(action))
                didEmitSwipe = true
            }
        }
        commands.append(contentsOf: scrollEngine.cancel())
        if mouseIsDown {
            commands.append(.mouseUp)
            mouseIsDown = false
        }
        resetTracking()
        mode = .cancelled
        let idle = GestureOutput(
            commands: commands,
            animation: makeAnimation(fingers: [], size: size, down: false, dragging: false),
            debug: makeDebug()
        )
        mode = .idle
        return idle
    }

    private func began(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        Haptics.prepare()
        replaceActive(active)
        maxClusterCount = max(maxClusterCount, fingers.count)
        startTime = timestamp
        lastTimestamp = timestamp
        peakMovement = 0
        swipeAxis = nil
        committedAction = nil
        didEmitSwipe = false
        lastDx = 0
        lastDy = 0
        let points = currentPoints()
        startCentroid = centroid(points)
        lastCentroid = startCentroid

        var commands = takeQueued()
        let cancelScroll = applyCount(fingers.count, timestamp: timestamp, points: points)
        commands.append(contentsOf: cancelScroll)
        lastFingerIDs = Set(fingers.keys)
        snapshotPreviousFingers()
        return GestureOutput(
            commands: commands,
            animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: mouseIsDown),
            debug: makeDebug()
        )
    }

    private func moved(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        replaceActive(active)
        if fingers.isEmpty {
            return ended(changed: changed, active: [], timestamp: timestamp, size: size)
        }
        maxClusterCount = max(maxClusterCount, fingers.count)
        let dt = max(timestamp - lastTimestamp, 0.0008)
        let points = currentPoints()
        let center = centroid(points)
        if let start = startCentroid {
            peakMovement = max(peakMovement, hypot(center.x - start.x, center.y - start.y))
        }

        var commands = takeQueued()
        let ids = Set(fingers.keys)
        if ids != lastFingerIDs {
            // Sticky multi-finger: once we've seen 3+ contacts, do not demote to
            // 2-finger scroll if iOS briefly drops a touch before the swipe locks.
            let stickyTwo = maxClusterCount >= 2
                && fingers.count == 1
                && (mode == .twoFingerCandidate || mode == .scrolling || mode == .pinching)
            let stickyThree = maxClusterCount >= 3
                && fingers.count > 0
                && fingers.count < 3
                && (mode == .threeFingerCandidate || mode == .threeFingerSwipe || mode == .twoFingerCandidate || mode == .scrolling)
            let stickyFour = maxClusterCount >= 4
                && fingers.count > 0
                && fingers.count < 4
                && (mode == .fourFingerCandidate || mode == .fourFingerSwipe || mode == .threeFingerCandidate || mode == .threeFingerSwipe)
            if stickyTwo {
                lastFingerIDs = ids
                lastCentroid = center
                lastTimestamp = timestamp
                snapshotPreviousFingers()
                return GestureOutput(
                    commands: commands,
                    animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: false),
                    debug: makeDebug()
                )
            }
            if stickyFour {
                if mode != .fourFingerSwipe { mode = .fourFingerCandidate }
                lastFingerIDs = ids
                var swipeCommands = processFourFingerSwipe(center: center)
                commands.append(contentsOf: swipeCommands)
                lastCentroid = center
                lastTimestamp = timestamp
                return GestureOutput(
                    commands: commands,
                    animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: false),
                    debug: makeDebug()
                )
            }
            if stickyThree {
                if mode != .threeFingerSwipe { mode = .threeFingerCandidate }
                lastFingerIDs = ids
                var swipeCommands = processThreeFingerSwipe(center: center)
                commands.append(contentsOf: swipeCommands)
                lastCentroid = center
                lastTimestamp = timestamp
                return GestureOutput(
                    commands: commands,
                    animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: false),
                    debug: makeDebug()
                )
            }
            if mode != .threeFingerSwipe && mode != .fourFingerSwipe {
                let cancelScroll = applyCount(fingers.count, timestamp: timestamp, points: points)
                commands.append(contentsOf: cancelScroll)
                lastFingerIDs = ids
                lastCentroid = center
                lastTimestamp = timestamp
                return GestureOutput(
                    commands: commands,
                    animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: mouseIsDown),
                    debug: makeDebug()
                )
            }
            lastFingerIDs = ids
        }

        switch mode {
        case .tapCandidate, .pointer, .dragPending, .dragging:
            if peakMovement > 8 {
                cancelLongPress()
                if mode == .tapCandidate { mode = .pointer }
            }
            if mode != .tapCandidate, let previous = lastCentroid {
                let dx = Double(center.x - previous.x)
                let dy = Double(center.y - previous.y)
                if hypot(dx, dy) >= 0.4 {
                    let accelerated = accelerate(dx: dx, dy: dy, dt: min(max(dt, 1.0 / 240.0), 1.0 / 30.0))
                    commands.append(.move(dx: accelerated.dx, dy: accelerated.dy))
                }
            }
        case .twoFingerCandidate, .scrolling, .pinching:
            commands.append(contentsOf: scrollEngine.move(points: points, timestamp: timestamp))
            switch scrollEngine.intent {
            case .scroll: mode = .scrolling
            case .pinch:
                mode = preferences.pinchEnabled ? .pinching : .twoFingerCandidate
            case .unknown: mode = .twoFingerCandidate
            }
        case .threeFingerCandidate, .threeFingerSwipe:
            commands.append(contentsOf: processThreeFingerSwipe(center: center))
        case .fourFingerCandidate, .fourFingerSwipe:
            commands.append(contentsOf: processFourFingerSwipe(center: center))
        case .idle, .cancelled:
            break
        }

        lastCentroid = center
        lastTimestamp = timestamp
        snapshotPreviousFingers()
        return GestureOutput(
            commands: commands,
            animation: makeAnimation(
                fingers: currentAnimationFingers(),
                size: size,
                down: fingers.isEmpty == false,
                dragging: mouseIsDown || mode == .dragging
            ),
            debug: makeDebug()
        )
    }

    private func ended(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, size: CGSize) -> GestureOutput {
        replaceActive(active)
        var commands = takeQueued()
        let remaining = fingers.count
        let duration = timestamp - startTime
        let isTap = peakMovement < 14 && duration < 0.35

        // If in an active 3 or 4 finger swipe, do NOT cancel when individual fingers lift asynchronously.
        // Wait until all fingers have released (remaining == 0).
        if (mode == .threeFingerSwipe || mode == .fourFingerSwipe) && remaining > 0 {
            lastCentroid = centroid(currentPoints())
            snapshotPreviousFingers()
            return GestureOutput(
                commands: commands,
                animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: false),
                debug: makeDebug()
            )
        }
        if remaining > 0 && (mode == .scrolling || mode == .pinching || mode == .twoFingerCandidate) && maxClusterCount >= 2 {
            lastCentroid = centroid(currentPoints())
            lastFingerIDs = Set(fingers.keys)
            snapshotPreviousFingers()
            return GestureOutput(
                commands: commands,
                animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: false),
                debug: makeDebug()
            )
        }

        if remaining == 0 {
            cancelLongPress()
            switch mode {
            case .dragging:
                commands.append(.mouseUp)
                mouseIsDown = false
                Haptics.dragEnd()
            case .threeFingerSwipe:
                // Already fired on lock; avoid double-firing the same system action.
                break
            case .fourFingerSwipe:
                break
            case .threeFingerCandidate:
                // Soft swipe that never quite locked — still honor cumulative direction.
                lastCentroid = lastCentroid ?? centroid(currentPoints())
                if didEmitSwipe == false, peakMovement > 14, let action = threeFingerActionFromPeak(), action != .none {
                    commands.append(.system(action))
                    didEmitSwipe = true
                    Haptics.gesture()
                } else if isTap, maxClusterCount == 3 {
                    commands.append(.shortcut("cmd+ctrl+d"))
                    Haptics.click()
                }
            case .fourFingerCandidate:
                lastCentroid = lastCentroid ?? centroid(currentPoints())
                if didEmitSwipe == false, peakMovement > 14, let action = fourFingerActionFromPeak(), action != .none {
                    commands.append(.system(action))
                    didEmitSwipe = true
                    Haptics.gesture()
                }
            case .twoFingerCandidate, .scrolling, .pinching:
                let scrollEnd = scrollEngine.end(isTap: isTap)
                if isTap, maxClusterCount == 2, preferences.twoFingerSecondaryClick {
                    commands.append(.rightClick)
                    Haptics.rightClick()
                } else {
                    commands.append(contentsOf: scrollEnd)
                }
            case .tapCandidate, .pointer, .dragPending:
                if mouseIsDown {
                    commands.append(.mouseUp)
                    mouseIsDown = false
                } else if isTap, maxClusterCount == 1, preferences.tapToClick {
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
            default:
                if mouseIsDown {
                    commands.append(.mouseUp)
                    mouseIsDown = false
                }
                commands.append(contentsOf: scrollEngine.cancel())
            }
            resetTracking()
            mode = .idle
            return GestureOutput(
                commands: commands,
                animation: makeAnimation(fingers: [], size: size, down: false, dragging: false),
                debug: makeDebug()
            )
        }

        let cancelScroll = applyCount(remaining, timestamp: timestamp, points: currentPoints())
        commands.append(contentsOf: cancelScroll)
        lastCentroid = centroid(currentPoints())
        lastFingerIDs = Set(fingers.keys)
        snapshotPreviousFingers()
        return GestureOutput(
            commands: commands,
            animation: makeAnimation(fingers: currentAnimationFingers(), size: size, down: true, dragging: mouseIsDown),
            debug: makeDebug()
        )
    }

    @discardableResult
    private func applyCount(_ count: Int, timestamp: TimeInterval, points: [CGPoint]) -> [RemoteCommand] {
        cancelLongPress()
        // Finger-count changes must not reuse the previous centroid or pointer deltas.
        lastDx = 0
        lastDy = 0
        startCentroid = centroid(points)
        lastCentroid = startCentroid
        peakMovement = 0
        swipeAxis = nil
        committedAction = nil

        switch count {
        case 1:
            mode = mouseIsDown ? .dragging : (mode == .idle ? .tapCandidate : .pointer)
            if mode == .tapCandidate { scheduleLongPress() }
            return scrollEngine.cancel()
        case 2:
            mode = .twoFingerCandidate
            return scrollEngine.begin(points: points, timestamp: timestamp)
        case 3:
            mode = .threeFingerCandidate
            return scrollEngine.cancel()
        case 4...:
            mode = .fourFingerCandidate
            return scrollEngine.cancel()
        default:
            mode = .idle
            return scrollEngine.cancel()
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
        let maxStep = 64.0 * max(preferences.effectiveSensitivity, 0.6)
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

    /// Infer direction from cumulative centroid when the swipe never fully locked an axis.
    private func threeFingerActionFromPeak() -> SystemAction? {
        guard let start = startCentroid, let current = lastCentroid else { return nil }
        let dx = current.x - start.x
        let dy = current.y - start.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? preferences.bindings.threeFingerRight : preferences.bindings.threeFingerLeft
        }
        return dy > 0 ? preferences.bindings.threeFingerDown : preferences.bindings.threeFingerUp
    }

    private func fourFingerActionFromPeak() -> SystemAction? {
        guard let start = startCentroid, let current = lastCentroid else { return nil }
        let dx = current.x - start.x
        let dy = current.y - start.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? preferences.bindings.fourFingerRight : preferences.bindings.fourFingerLeft
        }
        return dy > 0 ? preferences.bindings.fourFingerDown : preferences.bindings.fourFingerUp
    }

    private func processThreeFingerSwipe(center: CGPoint) -> [RemoteCommand] {
        guard let start = startCentroid else { return [] }
        let dx = center.x - start.x
        let dy = center.y - start.y
        if hypot(dx, dy) > 14 {
            let wasLocked = mode == .threeFingerSwipe
            mode = .threeFingerSwipe
            lastCentroid = center
            lockAxis(dx: dx, dy: dy)
            let action = threeFingerAction()
            committedAction = action
            if wasLocked == false, didEmitSwipe == false, let action, action != .none {
                didEmitSwipe = true
                Haptics.gesture()
                return [.system(action)]
            }
        }
        return []
    }

    private func processFourFingerSwipe(center: CGPoint) -> [RemoteCommand] {
        guard let start = startCentroid else { return [] }
        let dx = center.x - start.x
        let dy = center.y - start.y
        if hypot(dx, dy) > 14 {
            let wasLocked = mode == .fourFingerSwipe
            mode = .fourFingerSwipe
            lastCentroid = center
            lockAxis(dx: dx, dy: dy)
            let action = fourFingerAction()
            committedAction = action
            if wasLocked == false, didEmitSwipe == false, let action, action != .none {
                didEmitSwipe = true
                Haptics.gesture()
                return [.system(action)]
            }
        }
        return []
    }

    private func lockAxis(dx: CGFloat, dy: CGFloat) {
        if swipeAxis == nil {
            // Slight horizontal bias — desktop left/right swipes should lock easily.
            swipeAxis = abs(dx) >= abs(dy) * 0.75 ? .horizontal : .vertical
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
        previousFingers.removeAll()
        lastCentroid = nil
        startCentroid = nil
        swipeAxis = nil
        committedAction = nil
        didEmitSwipe = false
        lastDx = 0
        lastDy = 0
        peakMovement = 0
        maxClusterCount = 0
        lastFingerIDs.removeAll()
    }

    private func snapshotPreviousFingers() {
        previousFingers = fingers
    }

    private func currentPoints() -> [CGPoint] {
        fingers.keys.sorted().compactMap { fingers[$0] }
    }

    private func currentAnimationFingers() -> [TouchAnimationFinger] {
        fingers.keys.sorted().compactMap { id in
            guard let pt = fingers[id] else { return nil }
            let previous = previousFingers[id] ?? pt
            return TouchAnimationFinger(
                id: id,
                point: pt,
                previousPoint: previous,
                velocity: CGSize(width: pt.x - previous.x, height: pt.y - previous.y)
            )
        }
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private func makeAnimation(fingers: [TouchAnimationFinger], size: CGSize, down: Bool, dragging: Bool) -> TouchAnimationState {
        let start = startCentroid ?? .zero
        let current = lastCentroid ?? start
        let progress = CGSize(width: current.x - start.x, height: current.y - start.y)

        return TouchAnimationState(
            isConnected: isConnected,
            fingerCount: fingers.count,
            fingers: fingers,
            velocity: CGSize(width: lastDx, height: lastDy),
            isFingerDown: down,
            isDragging: dragging,
            clickPulse: clickPulse,
            doubleClickPulse: doubleClickPulse,
            trackpadSize: size,
            modeName: mode.rawValue,
            isPrecision: precisionActive,
            scrollIntent: scrollEngine.intent.rawValue,
            gestureProgress: progress,
            lockedAction: committedAction
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
