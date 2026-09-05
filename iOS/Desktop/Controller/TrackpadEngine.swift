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

    /// Window movement must be a deliberate title-bar hold, never a side effect
    /// of ordinary pointer travel. Keeping this time-based gate deterministic
    /// avoids adding a timer/display-link while still requiring a clear pause.
    private static let windowDragHoldDuration: TimeInterval = 1.50
    private static let windowDragPreHoldMovementTolerance: CGFloat = 8.0

    /// Two-finger movement normally means scrolling. Resizing is only armed when
    /// two fingers are held almost still first, so a normal smooth up/down gesture
    /// can never be stolen just because the pointer happens to sit near a window edge.
    private static let resizeHoldDuration: TimeInterval = 0.32
    private static let resizePreHoldMovementTolerance: CGFloat = 3.5

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
    private var dragHoldEligible = true
    private var threeFingerActionFired = false
    /// Three-finger controller gestures must begin only after the third finger is
    /// actually present. Reusing the original one-finger centroid can inherit
    /// earlier pointer motion and accidentally trigger Overview/window switching.
    private var threeFingerStartCentroid: CGPoint?
    private var twoFingerStartTime: TimeInterval?
    private var twoFingerMovementDistance: CGFloat = 0
    private var scrollVelocity: CGSize = .zero
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
            dragHoldEligible = true
            threeFingerActionFired = false
            threeFingerStartCentroid = nil
            twoFingerStartTime = nil
            twoFingerMovementDistance = 0
            scrollVelocity = .zero
            resetPointerSmoothing()
            secondTapCandidate = now - lastTapTime <= 0.30
            addRipple(at: center)
        } else {
            // Finger-count changes must not create a cursor/scroll jump.
            lastCentroid = center
            lastSampleTime = now
            gestureFingerCount = max(gestureFingerCount, activeFingers)
            if activeFingers == 3 && lastObservedFingerCount != 3 {
                threeFingerStartCentroid = center
            } else if activeFingers != 3 {
                threeFingerStartCentroid = nil
            }
            if activeFingers == 2 && lastObservedFingerCount != 2 {
                twoFingerStartTime = now
                twoFingerMovementDistance = 0
            } else if activeFingers != 2 {
                twoFingerStartTime = nil
                twoFingerMovementDistance = 0
            }
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
            if activeFingers == 3 {
                threeFingerStartCentroid = center
            } else {
                threeFingerStartCentroid = nil
            }
            if activeFingers == 2 {
                twoFingerStartTime = now
                twoFingerMovementDistance = 0
            } else {
                twoFingerStartTime = nil
                twoFingerMovementDistance = 0
            }
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
        if activeFingers == 2 {
            twoFingerMovementDistance += deltaDistance
        }
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
            handleTwoFingerInteraction(
                dx: rawDX,
                dy: rawDY,
                dt: dt,
                now: now,
                desktop: desktop,
                settings: settings
            )

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
        let endedState = state
        let wasDragLocked = endedState == .dragLocked

        activeFingers = max(remainingTouchCount, 0)
        lastObservedFingerCount = activeFingers
        if activeFingers != 3 {
            threeFingerStartCentroid = nil
        }
        if activeFingers != 2 {
            twoFingerStartTime = nil
            twoFingerMovementDistance = 0
        }

        // Evaluate click semantics only when the complete gesture has ended.
        guard remainingTouchCount == 0 else {
            // Keep the sampling origin on the fingers that are actually still
            // touching the trackpad. Resetting it to .zero made the next move
            // sample look enormous and could produce a scroll jump after a
            // finger was lifted from a multi-touch gesture.
            let remainingTouches = activeTouchesBeforeEnd.subtracting(endingTouches)
            if remainingTouches.count == remainingTouchCount {
                let now = CACurrentMediaTime()
                lastCentroid = centroid(of: remainingTouches, in: view)
                lastSampleTime = now
                if activeFingers == 2 {
                    twoFingerStartTime = now
                    twoFingerMovementDistance = 0
                }
                if activeFingers == 3 {
                    threeFingerStartCentroid = lastCentroid
                }
            } else {
                // Defensive fallback for an unexpected UIKit callback shape. The
                // gesture role guards below still prevent cross-gesture actions.
                lastCentroid = .zero
            }
            resetPointerSmoothing()
            return
        }

        if endedState == .dragging {
            desktop.endWindowDrag()
        } else if endedState == .resizing {
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
                // A two-finger tap becomes context click only if no scrolling or
                // resize movement crossed the tap threshold. Route it through the
                // same active WebView registry used by normal pointer input.
                if settings.hapticsEnabled { Haptics.rightClick() }
                desktop.contextClickAtCursorUsingRegistry()
            }
        } else if endedState == .scrolling,
                  completedFingerCount == 2,
                  settings.scrollMomentum {
            startMomentum(initialVelocity: scrollVelocity, desktop: desktop)
        }

        if state != .dragLocked {
            state = .idle
            desktop.cancelPointerManipulation()
        }

        gestureFingerCount = 0
        totalMovementDistance = 0
        secondTapCandidate = false
        dragHoldEligible = true
        threeFingerActionFired = false
        threeFingerStartCentroid = nil
        twoFingerStartTime = nil
        twoFingerMovementDistance = 0
        scrollVelocity = .zero
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
        dragHoldEligible = true
        threeFingerActionFired = false
        threeFingerStartCentroid = nil
        twoFingerStartTime = nil
        twoFingerMovementDistance = 0
        scrollVelocity = .zero
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

        let heldDuration = now - gestureStartTime

        // Ordinary one-finger pointer travel permanently disqualifies this touch
        // from becoming a window drag. The user must first park the cursor over
        // a title bar, hold nearly still, then move after the hold threshold.
        if heldDuration < Self.windowDragHoldDuration,
           totalMovementDistance > Self.windowDragPreHoldMovementTolerance {
            dragHoldEligible = false
        }

        let wantsManipulation = dragHoldEligible &&
            heldDuration >= Self.windowDragHoldDuration &&
            totalMovementDistance > 1.0

        if wantsManipulation, desktop.beginWindowDrag() {
            // Drag Lock remains available only through an equally deliberate
            // second-tap-and-hold. A normal long hold behaves like direct drag.
            state = secondTapCandidate && settings.dragLock ? .dragLocked : .dragging
            resetPointerSmoothing()
            if settings.hapticsEnabled { Haptics.touchTap() }
            let delta = acceleratedDelta(dx: dx, dy: dy, dt: dt, settings: settings)
            desktop.updateWindowDrag(delta: delta)
            return
        }

        state = .moving
        let delta = stabilizedPointerDelta(dx: dx, dy: dy, dt: dt, settings: settings)
        desktop.movePointer(delta: delta, sensitivity: 1.0)
    }

    // MARK: - Two Finger Scroll / Resize

    private func handleTwoFingerInteraction(
        dx: CGFloat,
        dy: CGFloat,
        dt: TimeInterval,
        now: TimeInterval,
        desktop: DesktopSession,
        settings: TrackpadSettings
    ) {
        // Once a gesture has ever involved three or more fingers, the remaining
        // fingers still belong to that gesture. Do not reinterpret a 3→2 lift as
        // a new scroll/resize gesture; require every finger to lift first.
        guard gestureFingerCount <= 2 else { return }

        // Resizing is intentionally owned by exactly two fingers. Once armed,
        // keep routing the gesture exclusively to the resize path.
        if state == .resizing {
            desktop.updatePointerResize(delta: CGSize(width: dx, height: dy))
            return
        }

        // Once ordinary two-finger movement has become a scroll, never switch it
        // into resize midway through the same gesture just because the cursor is
        // near an edge. This is what makes long, smooth up/down scrolling stable.
        if state == .scrolling {
            handleTwoFingerScroll(dx: dx, dy: dy, dt: dt, desktop: desktop, settings: settings)
            return
        }

        let heldDuration = now - (twoFingerStartTime ?? now)

        // Ignore tiny resting jitter while determining intent. A resize requires
        // a deliberate two-finger pause first; moving past the tolerance before
        // the hold expires immediately commits the gesture to scrolling.
        guard twoFingerMovementDistance > Self.resizePreHoldMovementTolerance else { return }

        if heldDuration >= Self.resizeHoldDuration,
           desktop.beginPointerResize() {
            state = .resizing
            scrollVelocity = .zero
            if settings.hapticsEnabled { Haptics.touchTap() }
            desktop.updatePointerResize(delta: CGSize(width: dx, height: dy))
            return
        }

        state = .scrolling
        handleTwoFingerScroll(dx: dx, dy: dy, dt: dt, desktop: desktop, settings: settings)
    }

    private func handleTwoFingerScroll(
        dx: CGFloat,
        dy: CGFloat,
        dt: TimeInterval,
        desktop: DesktopSession,
        settings: TrackpadSettings
    ) {
        state = .scrolling

        let delta = Self.scrollDelta(
            dx: dx,
            dy: dy,
            speed: settings.scrollSpeed,
            naturalScrolling: settings.naturalScrolling
        )
        guard hypot(delta.width, delta.height) > 0.10 else { return }

        desktop.scrollActiveWindow(deltaX: delta.width, deltaY: delta.height)

        let instantaneous = CGSize(
            width: delta.width / CGFloat(dt),
            height: delta.height / CGFloat(dt)
        )
        scrollVelocity = CGSize(
            width: scrollVelocity.width * 0.72 + instantaneous.width * 0.28,
            height: scrollVelocity.height * 0.72 + instantaneous.height * 0.28
        )
    }

    /// Symmetric two-axis scroll conversion. Keeping this pure makes vertical
    /// and horizontal behavior testable and prevents one axis from feeling heavier.
    static func scrollDelta(
        dx: CGFloat,
        dy: CGFloat,
        speed: Double,
        naturalScrolling: Bool
    ) -> CGSize {
        let gain = CGFloat(speed) * 1.30
        let direction: CGFloat = naturalScrolling ? 1 : -1
        return CGSize(width: dx * gain * direction, height: dy * gain * direction)
    }

    private func startMomentum(initialVelocity: CGSize, desktop: DesktopSession) {
        stopMomentum()
        guard hypot(initialVelocity.width, initialVelocity.height) > 35,
              let momentumWindowID = desktop.activeWindowID else { return }

        momentumTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var velocity = CGSize(
                width: min(max(initialVelocity.width, -2600), 2600),
                height: min(max(initialVelocity.height, -2600), 2600)
            )

            // Momentum is the only part of the trackpad that needs an active
            // cadence after fingers lift. Run it at the iPhone controller's
            // available refresh rate (capped at 120 Hz) and stop the task as
            // soon as velocity settles. This improves ProMotion smoothness
            // without introducing an idle display-link loop or making any claim
            // about the external display's independently negotiated refresh rate.
            let refreshRate = min(max(UIScreen.main.maximumFramesPerSecond, 60), 120)
            let frameDuration = 1.0 / Double(refreshRate)
            let sleepMilliseconds = refreshRate >= 100 ? 8 : 16
            let decayPer60HzFrame = 0.93
            let decay = CGFloat(pow(decayPer60HzFrame, frameDuration / (1.0 / 60.0)))

            while !Task.isCancelled &&
                    desktop.activeWindowID == momentumWindowID &&
                    hypot(velocity.width, velocity.height) > 12 {
                desktop.scrollActiveWindow(
                    deltaX: velocity.width * CGFloat(frameDuration),
                    deltaY: velocity.height * CGFloat(frameDuration)
                )
                velocity.width *= decay
                velocity.height *= decay
                try? await Task.sleep(for: .milliseconds(sleepMilliseconds))
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
        guard !threeFingerActionFired,
              let origin = threeFingerStartCentroid else { return }

        let totalDX = center.x - origin.x
        let totalDY = center.y - origin.y

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
