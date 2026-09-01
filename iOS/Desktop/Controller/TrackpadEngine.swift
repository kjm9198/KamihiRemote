import SwiftUI
import UIKit

/// High-performance trackpad gesture state machine and velocity physics engine.
///
/// Important: callers should use the `handleGesture...` APIs with the complete
/// tracked touch set. UIKit's `touches` callback parameter only contains the
/// touches that changed, which is not a reliable finger-count signal.
@MainActor
final class TrackpadEngine: ObservableObject {
    enum State: String, Equatable {
        case idle = "Idle"
        case moving = "Moving"
        case scrolling = "Scrolling"
        case dragging = "Dragging"
        case dragLocked = "Drag Locked"
        case resizing = "Resizing"
    }

    struct TouchRipple: Identifiable, Equatable {
        let id = UUID()
        var point: CGPoint
        var radius: CGFloat
        var opacity: Double
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var activeFingers: Int = 0
    @Published var isPrecisionMode: Bool = false
    @Published private(set) var ripples: [TouchRipple] = []

    private var gestureStartTime: TimeInterval = 0
    private var lastSampleTime: TimeInterval = 0
    private var lastTapTime: TimeInterval = 0
    private var initialCentroid: CGPoint = .zero
    private var lastCentroid: CGPoint = .zero
    private var totalMovementDistance: CGFloat = 0
    private var gestureFingerCount: Int = 0
    private var lastObservedFingerCount: Int = 0
    private var secondTapCandidate = false
    private var threeFingerActionFired = false
    private var scrollVelocity: CGFloat = 0
    private var previousPointerDelta: CGSize = .zero
    private var hasPreviousPointerDelta = false
    private var momentumTask: Task<Void, Never>?

    var onThreeFingerSwipeUp: (() -> Void)?
    var onThreeFingerSwipeLeft: (() -> Void)?
    var onThreeFingerSwipeRight: (() -> Void)?

    init() {}

    // MARK: - Complete-touch-set APIs

    func handleGestureBegan(_ activeTouches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        stopMomentum()

        activeFingers = activeTouches.count
        gestureFingerCount = max(gestureFingerCount, activeFingers)
        guard !activeTouches.isEmpty else { return }

        let now = CACurrentMediaTime()
        let center = centroid(of: activeTouches, in: view)

        // A brand-new gesture starts when the first finger goes down.
        if activeFingers == 1 && lastObservedFingerCount == 0 {
            gestureStartTime = now
            lastSampleTime = now
            initialCentroid = center
            lastCentroid = center
            totalMovementDistance = 0
            gestureFingerCount = 1
            threeFingerActionFired = false
            scrollVelocity = 0
            resetPointerSmoothing()
            secondTapCandidate = now - lastTapTime <= 0.30
            addRipple(at: center)
        } else {
            // Finger-count changes must not create a cursor/scroll jump.
            lastCentroid = center
            lastSampleTime = now
            gestureFingerCount = max(gestureFingerCount, activeFingers)
            resetPointerSmoothing()
        }

        lastObservedFingerCount = activeFingers
    }

    func handleGestureMoved(_ activeTouches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        activeFingers = activeTouches.count
        guard activeFingers > 0 else { return }

        let now = CACurrentMediaTime()
        let center = centroid(of: activeTouches, in: view)

        // When a second/third finger joins or leaves, reset the sampling origin
        // and consume that sample. This prevents the classic multi-touch jump.
        if activeFingers != lastObservedFingerCount {
            lastObservedFingerCount = activeFingers
            gestureFingerCount = max(gestureFingerCount, activeFingers)
            lastCentroid = center
            lastSampleTime = now
            resetPointerSmoothing()
            return
        }

        let dt = max(now - lastSampleTime, 1.0 / 240.0)
        let rawDX = center.x - lastCentroid.x
        let rawDY = center.y - lastCentroid.y
        let deltaDistance = hypot(rawDX, rawDY)

        lastCentroid = center
        lastSampleTime = now
        totalMovementDistance += deltaDistance
        gestureFingerCount = max(gestureFingerCount, activeFingers)

        switch activeFingers {
        case 1:
            handleOneFingerMove(
                dx: rawDX,
                dy: rawDY,
                dt: dt,
                now: now,
                desktop: desktop,
                settings: settings
            )

        case 2:
            handleTwoFingerScroll(dy: rawDY, dt: dt, desktop: desktop, settings: settings)

        case 3:
            handleThreeFingerGesture(center: center)

        default:
            state = .idle
        }
    }

    func handleGestureEnded(
        activeTouchesBeforeEnd: Set<UITouch>,
        endingTouches: Set<UITouch>,
        remainingTouchCount: Int,
        in view: UIView,
        desktop: DesktopSession,
        settings: TrackpadSettings
    ) {
        let duration = CACurrentMediaTime() - gestureStartTime
        let wasTap = duration < 0.26 && totalMovementDistance < 10
        let completedFingerCount = max(gestureFingerCount, activeTouchesBeforeEnd.count)
        let wasDragLocked = state == .dragLocked

        activeFingers = max(remainingTouchCount, 0)
        lastObservedFingerCount = activeFingers

        // Evaluate click semantics only when the complete gesture has ended.
        guard remainingTouchCount == 0 else {
            lastCentroid = .zero
            resetPointerSmoothing()
            return
        }

        if state == .dragging {
            desktop.endWindowDrag()
        } else if state == .resizing {
            desktop.endPointerResize()
        }

        if wasTap {
            if wasDragLocked && completedFingerCount == 1 {
                // Native-style drag lock: the next clean one-finger tap drops
                // the item/window instead of leaking an unrelated click through.
                desktop.endWindowDrag()
                desktop.endPointerResize()
                state = .idle
                if settings.hapticsEnabled { Haptics.touchTap() }
            } else if completedFingerCount == 1 && settings.tapToClick {
                if settings.hapticsEnabled { Haptics.click() }
                desktop.clickAtCursor()
                lastTapTime = CACurrentMediaTime()
            } else if completedFingerCount == 2 {
                // A two-finger tap becomes context click only if no scrolling
                // movement crossed the tap threshold.
                if settings.hapticsEnabled { Haptics.rightClick() }
                desktop.contextClickAtCursor()
            }
        } else if completedFingerCount == 2 && settings.scrollMomentum {
            startMomentum(initialVelocity: scrollVelocity, desktop: desktop)
        }

        if state != .dragLocked {
            state = .idle
            desktop.cancelPointerManipulation()
        }

        gestureFingerCount = 0
        totalMovementDistance = 0
        secondTapCandidate = false
        threeFingerActionFired = false
        scrollVelocity = 0
        resetPointerSmoothing()
    }

    func handleGestureCancelled(desktop: DesktopSession) {
        stopMomentum()
        state = .idle
        activeFingers = 0
        gestureFingerCount = 0
        lastObservedFingerCount = 0
        totalMovementDistance = 0
        secondTapCandidate = false
        threeFingerActionFired = false
        scrollVelocity = 0
        resetPointerSmoothing()
        desktop.cancelPointerManipulation()
    }

    func unlockDrag(desktop: DesktopSession) {
        guard state == .dragLocked else { return }
        state = .idle
        desktop.endWindowDrag()
        desktop.endPointerResize()
        desktop.cancelPointerManipulation()
        resetPointerSmoothing()
    }

    // MARK: - Compatibility APIs
    // Kept temporarily so older debug surfaces continue compiling while all
    // production callers migrate to the complete-touch-set APIs above.

    func handleTouchesBegan(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        handleGestureBegan(touches, in: view, desktop: desktop, settings: settings)
    }

    func handleTouchesMoved(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        handleGestureMoved(touches, in: view, desktop: desktop, settings: settings)
    }

    func handleTouchesEnded(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        handleGestureEnded(
            activeTouchesBeforeEnd: touches,
            endingTouches: touches,
            remainingTouchCount: 0,
            in: view,
            desktop: desktop,
            settings: settings
        )
    }

    func handleTouchesCancelled(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession) {
        handleGestureCancelled(desktop: desktop)
    }

    // MARK: - One Finger

    private func handleOneFingerMove(
        dx: CGFloat,
        dy: CGFloat,
        dt: TimeInterval,
        now: TimeInterval,
        desktop: DesktopSession,
        settings: TrackpadSettings
    ) {
        // Once a gesture has ever contained 2+ fingers, the remaining finger
        // after a lift belongs to that multi-touch gesture. It must not suddenly
        // become pointer input before every finger is lifted and a new gesture starts.
        guard gestureFingerCount <= 1 else { return }

        let distance = hypot(dx, dy)
        guard distance > 0.16 else { return }

        if state == .dragLocked || state == .dragging {
            let delta = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
            desktop.updateWindowDrag(delta: delta)
            return
        }

        if state == .resizing {
            let delta = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
            desktop.updatePointerResize(delta: delta)
            return
        }

        let heldDuration = now - gestureStartTime
        let wantsManipulation =
            (secondTapCandidate && totalMovementDistance > 3.0) ||
            (heldDuration > 0.34 && totalMovementDistance > 5.0)

        if wantsManipulation {
            // Resize has priority when the pointer is on a window edge/corner.
            if desktop.beginPointerResize() {
                state = .resizing
                resetPointerSmoothing()
                if settings.hapticsEnabled { Haptics.touchTap() }
                let delta = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
                desktop.updatePointerResize(delta: delta)
                return
            }

            if desktop.beginWindowDrag() {
                state = secondTapCandidate && settings.dragLock ? .dragLocked : .dragging
                resetPointerSmoothing()
                if settings.hapticsEnabled { Haptics.touchTap() }
                let delta = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
                desktop.updateWindowDrag(delta: delta)
                return
            }
        }

        state = .moving
        let delta = stabilizedPointerDelta(dx: dx, dy: dy, dt: dt, settings: settings)
        desktop.movePointer(delta: delta, sensitivity: 1.0)
    }

    // MARK: - Two Finger Scroll

    private func handleTwoFingerScroll(
        dy: CGFloat,
        dt: TimeInterval,
        desktop: DesktopSession,
        settings: TrackpadSettings
    ) {
        // Once two-finger movement becomes scrolling, a click must not leak out.
        state = .scrolling

        var scrollDelta = dy * CGFloat(settings.scrollSpeed) * 1.30
        if !settings.naturalScrolling {
            scrollDelta = -scrollDelta
        }

        guard abs(scrollDelta) > 0.10 else { return }
        desktop.scrollActiveWindow(deltaY: scrollDelta)

        let instantaneousVelocity = scrollDelta / CGFloat(dt)
        scrollVelocity = scrollVelocity * 0.72 + instantaneousVelocity * 0.28
    }

    private func startMomentum(initialVelocity: CGFloat, desktop: DesktopSession) {
        stopMomentum()
        guard abs(initialVelocity) > 35 else { return }

        momentumTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var velocity = min(max(initialVelocity, -2600), 2600)
            let frameDuration: CGFloat = 1.0 / 60.0

            while !Task.isCancelled && abs(velocity) > 12 {
                desktop.scrollActiveWindow(deltaY: velocity * frameDuration)
                // Slightly longer, smoother coast than the old 0.90 decay while
                // remaining bounded and stopping immediately on the next touch.
                velocity *= 0.93
                try? await Task.sleep(for: .milliseconds(16))
            }

            if self.activeFingers == 0 && self.state == .scrolling {
                self.state = .idle
            }
        }
    }

    private func stopMomentum() {
        momentumTask?.cancel()
        momentumTask = nil
    }

    // MARK: - Three Finger

    private func handleThreeFingerGesture(center: CGPoint) {
        guard !threeFingerActionFired else { return }

        let totalDX = center.x - initialCentroid.x
        let totalDY = center.y - initialCentroid.y

        if totalDY < -58 && abs(totalDX) < 46 {
            threeFingerActionFired = true
            onThreeFingerSwipeUp?()
        } else if totalDX < -58 && abs(totalDY) < 46 {
            threeFingerActionFired = true
            onThreeFingerSwipeLeft?()
        } else if totalDX > 58 && abs(totalDY) < 46 {
            threeFingerActionFired = true
            onThreeFingerSwipeRight?()
        }
    }

    // MARK: - Physics

    /// Produces a velocity-sensitive pointer delta without exponentiating each
    /// axis independently. Slow movement stays precise; fast sweeps gain reach.
    static func physicsDelta(
        dx: CGFloat,
        dy: CGFloat,
        dt: TimeInterval,
        sensitivity: Double,
        acceleration: Double,
        precisionMode: Bool
    ) -> CGSize {
        let distance = hypot(dx, dy)
        guard distance > 0 else { return .zero }

        let speed = distance / CGFloat(max(dt, 1.0 / 240.0))
        let precisionGain = 0.72 + min(speed / 180.0, 1.0) * 0.28
        let accelerationProgress = min(max((speed - 90.0) / 950.0, 0.0), 1.0)
        let accelerationGain = 1.0 + CGFloat(max(acceleration, 0)) * accelerationProgress * 1.15
        let modeGain: CGFloat = precisionMode ? 0.42 : 1.0
        let unclampedGain = precisionGain * accelerationGain * CGFloat(sensitivity) * modeGain
        // Keep extreme user settings useful on a 1080p desktop without allowing
        // a single fast sample to fling the pointer across the whole canvas.
        let gain = min(unclampedGain, precisionMode ? 2.2 : 4.6)

        return CGSize(width: dx * gain, height: dy * gain)
    }

    /// A one-sample adaptive low-pass filter. Slow, tiny movements get extra
    /// stabilization for precise targeting; fast sweeps stay nearly direct so
    /// smoothing never feels like visible cursor lag.
    static func smoothedDelta(current: CGSize, previous: CGSize?, rawSpeed: CGFloat) -> CGSize {
        guard let previous else { return current }
        let speedProgress = min(max((rawSpeed - 35.0) / 700.0, 0.0), 1.0)
        let currentWeight = 0.62 + speedProgress * 0.30
        let previousWeight = 1.0 - currentWeight
        return CGSize(
            width: current.width * currentWeight + previous.width * previousWeight,
            height: current.height * currentWeight + previous.height * previousWeight
        )
    }

    private func stabilizedPointerDelta(dx: CGFloat, dy: CGFloat, dt: TimeInterval, settings: TrackpadSettings) -> CGSize {
        let accelerated = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
        let rawSpeed = hypot(dx, dy) / CGFloat(max(dt, 1.0 / 240.0))
        let previous = hasPreviousPointerDelta ? previousPointerDelta : nil
        let output = Self.smoothedDelta(current: accelerated, previous: previous, rawSpeed: rawSpeed)
        previousPointerDelta = output
        hasPreviousPointerDelta = true
        return output
    }

    private func acceleratedDelta(dx: CGFloat, dy: CGFloat, dt: TimeInterval, settings: TrackpadSettings) -> CGSize {
        Self.physicsDelta(
            dx: dx,
            dy: dy,
            dt: dt,
            sensitivity: settings.pointerSensitivity,
            acceleration: settings.pointerAcceleration,
            precisionMode: isPrecisionMode
        )
    }

    private func resetPointerSmoothing() {
        previousPointerDelta = .zero
        hasPreviousPointerDelta = false
    }

    private func centroid(of touches: Set<UITouch>, in view: UIView) -> CGPoint {
        guard !touches.isEmpty else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        for touch in touches {
            let point = touch.location(in: view)
            x += point.x
            y += point.y
        }
        let count = CGFloat(touches.count)
        return CGPoint(x: x / count, y: y / count)
    }

    private func addRipple(at point: CGPoint) {
        let ripple = TouchRipple(point: point, radius: 8, opacity: 0.55)
        ripples.append(ripple)
        if ripples.count > 3 { ripples.removeFirst() }

        withAnimation(.easeOut(duration: 0.24)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].radius = 30
                ripples[idx].opacity = 0.0
            }
        }
    }
}
