import SwiftUI
import UIKit

/// High-performance trackpad gesture state machine and velocity physics engine.
@MainActor
final class TrackpadEngine: ObservableObject {
    enum State: String, Equatable {
        case idle = "Idle"
        case moving = "Moving"
        case scrolling = "Scrolling"
        case dragging = "Dragging"
        case dragLocked = "Drag Locked"
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

    private var touchStartTime: TimeInterval = 0
    private var lastTapTime: TimeInterval = 0
    private var initialTouchPoint: CGPoint = .zero
    private var lastTouchPoint: CGPoint = .zero
    private var totalMovementDistance: CGFloat = 0
    private var tapCount: Int = 0

    var onThreeFingerSwipeUp: (() -> Void)?
    var onThreeFingerSwipeLeft: (() -> Void)?
    var onThreeFingerSwipeRight: (() -> Void)?

    init() {}

    // MARK: - Touch Processing
    func handleTouchesBegan(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        activeFingers = touches.count
        guard let first = touches.first else { return }

        let now = CACurrentMediaTime()
        touchStartTime = now
        initialTouchPoint = first.location(in: view)
        lastTouchPoint = initialTouchPoint
        totalMovementDistance = 0

        if activeFingers == 1 {
            if now - lastTapTime < 0.28 {
                tapCount += 1
                if tapCount == 2 && settings.dragLock {
                    state = .dragLocked
                    if settings.hapticsEnabled { Haptics.touchTap() }
                    desktop.beginWindowDrag()
                }
            } else {
                tapCount = 1
            }
        }

        addRipple(at: initialTouchPoint)
    }

    func handleTouchesMoved(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        activeFingers = touches.count
        guard let first = touches.first else { return }

        let currentPoint = first.location(in: view)
        let dx = currentPoint.x - lastTouchPoint.x
        let dy = currentPoint.y - lastTouchPoint.y
        lastTouchPoint = currentPoint

        let deltaDistance = hypot(dx, dy)
        totalMovementDistance += deltaDistance

        // 1-Finger Pointer Movement & Dragging
        if activeFingers == 1 {
            if state != .dragLocked && state != .dragging {
                state = .moving
            }

            // Dead-zone filter (< 0.4pt)
            if deltaDistance > 0.4 {
                var sensitivity = settings.pointerSensitivity
                if isPrecisionMode { sensitivity *= 0.45 }

                // Non-linear velocity acceleration curve
                let acceleratedDx = accelerate(dx) * sensitivity
                let acceleratedDy = accelerate(dy) * sensitivity

                desktop.movePointer(delta: CGSize(width: acceleratedDx, height: acceleratedDy), sensitivity: 1.0)
            }
        }
        // 2-Finger Isolated Scrolling (Strictly no cursor movement)
        else if activeFingers == 2 {
            state = .scrolling
            var scrollDelta = dy * settings.scrollSpeed * 1.8
            if !settings.naturalScrolling {
                scrollDelta = -scrollDelta
            }
            desktop.scrollActiveWindow(deltaY: scrollDelta)
        }
        // 3-Finger Swipes
        else if activeFingers == 3 {
            let totalDx = currentPoint.x - initialTouchPoint.x
            let totalDy = currentPoint.y - initialTouchPoint.y

            if totalDy < -60 && abs(totalDx) < 40 {
                onThreeFingerSwipeUp?()
            } else if totalDx < -60 && abs(totalDy) < 40 {
                onThreeFingerSwipeLeft?()
            } else if totalDx > 60 && abs(totalDy) < 40 {
                onThreeFingerSwipeRight?()
            }
        }
    }

    func handleTouchesEnded(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession, settings: TrackpadSettings) {
        let duration = CACurrentMediaTime() - touchStartTime
        let wasTap = duration < 0.25 && totalMovementDistance < 12

        if wasTap {
            lastTapTime = CACurrentMediaTime()
            if activeFingers == 1 {
                // Primary Click
                if settings.hapticsEnabled { Haptics.click() }
                desktop.clickAtCursor()
            } else if activeFingers == 2 {
                // Context / Right Click
                if settings.hapticsEnabled { Haptics.rightClick() }
                desktop.contextClickAtCursor()
            }
        }

        if state == .dragging {
            desktop.endWindowDrag()
        }

        if state != .dragLocked {
            state = .idle
        }
        activeFingers = 0
    }

    func handleTouchesCancelled(_ touches: Set<UITouch>, in view: UIView, desktop: DesktopSession) {
        state = .idle
        activeFingers = 0
        desktop.endWindowDrag()
    }

    func unlockDrag(desktop: DesktopSession) {
        if state == .dragLocked {
            state = .idle
            desktop.endWindowDrag()
        }
    }

    // MARK: - Velocity Acceleration Math
    private func accelerate(_ val: CGFloat) -> CGFloat {
        let absVal = abs(val)
        let sign: CGFloat = val >= 0 ? 1.0 : -1.0
        // Exponential scaling for smooth micro-movements and swift sweeping motions
        let accelerated = pow(absVal, 1.18)
        return sign * accelerated
    }

    private func addRipple(at point: CGPoint) {
        let ripple = TouchRipple(point: point, radius: 10, opacity: 0.7)
        ripples.append(ripple)
        if ripples.count > 4 { ripples.removeFirst() }

        withAnimation(.easeOut(duration: 0.35)) {
            if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[idx].radius = 42
                ripples[idx].opacity = 0.0
            }
        }
    }
}
