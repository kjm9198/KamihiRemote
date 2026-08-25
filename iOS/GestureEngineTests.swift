import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GestureEngineTests {
    private static let size = CGSize(width: 390, height: 640)

    @discardableResult
    static func runSelfChecks() -> Bool {
        oneFingerMove()
        oneFingerTap()
        doubleClick()
        twoFingerTap()
        threeFingerTap()
        slowScroll()
        fastScrollMomentum()
        frameRateIndependence()
        horizontalThreeFingerSwipe()
        pinchDisabled()
        fingerCountTransitions()
        asyncThreeFingerRelease()
        threeFingerCumulative()
        fourFinger()
        animationFingerCounts()
        liftClearsAnimation()
        emptyMoveEndsGesture()
        NSLog("Kamihi gesture self-checks passed")
        return true
    }

    private static func engine(tapToClick: Bool = false) -> GestureEngine {
        let engine = GestureEngine()
        engine.preferences.tapToClick = tapToClick
        engine.preferences.twoFingerSecondaryClick = true
        engine.preferences.scrollFeel = .macLike
        return engine
    }

    private static func defaultEngine() -> GestureEngine {
        let engine = GestureEngine()
        precondition(engine.preferences.tapToClick == false, "tap to click off by default")
        return engine
    }

    private static func oneFingerMove() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 1, phase: .began, in: size)
        let moved = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 130, y: 108))], timestamp: 1.03, phase: .moved, in: size)
        precondition(moved.commands.contains { if case .move(let dx, _) = $0 { return dx > 0 } else { return false } }, "one finger move")
    }

    private static func oneFingerTap() {
        let g = engine(tapToClick: true)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.08, phase: .ended, in: size)
        precondition(ended.commands.contains(.click), "tap to click when enabled")
        let g2 = defaultEngine()
        _ = g2.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2, phase: .began, in: size)
        let noClick = g2.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.08, phase: .ended, in: size)
        precondition(noClick.commands.contains(.click) == false, "single tap must not click by default")
    }

    private static func doubleClick() {
        let g = engine(tapToClick: true)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 3, phase: .began, in: size)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 3.05, phase: .ended, in: size)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 80))], timestamp: 3.12, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 80))], timestamp: 3.18, phase: .ended, in: size)
        precondition(ended.commands.contains(.doubleClick), "double click")
    }

    private static func twoFingerTap() {
        let g = engine()
        let start = [FingerSample(id: 1, point: CGPoint(x: 90, y: 90)), FingerSample(id: 2, point: CGPoint(x: 140, y: 90))]
        _ = g.ingest(samples: start, timestamp: 4, phase: .began, in: size)
        let ended = g.ingest(samples: start, timestamp: 4.08, phase: .ended, in: size)
        precondition(ended.commands.contains(.rightClick), "two finger tap")
    }

    private static func threeFingerTap() {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 80, y: 90)),
            FingerSample(id: 2, point: CGPoint(x: 130, y: 90)),
            FingerSample(id: 3, point: CGPoint(x: 180, y: 90))
        ]
        _ = g.ingest(samples: start, timestamp: 4.5, phase: .began, in: size)
        let ended = g.ingest(samples: start, timestamp: 4.58, phase: .ended, in: size)
        precondition(ended.commands.contains(.shortcut("cmd+ctrl+d")), "three finger tap for Look Up")
    }

    private static func slowScroll() {
        let g = engine()
        let a = [FingerSample(id: 1, point: CGPoint(x: 90, y: 120)), FingerSample(id: 2, point: CGPoint(x: 150, y: 120))]
        _ = g.ingest(samples: a, timestamp: 5, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 90, y: 180)), FingerSample(id: 2, point: CGPoint(x: 150, y: 180))]
        let moved = g.ingest(samples: b, timestamp: 5.08, phase: .moved, in: size)
        precondition(moved.commands.contains { if case .scroll = $0 { return true } else { return false } }, "slow scroll")
        precondition(moved.debug.scrollIntent == "scroll" || moved.debug.mode.contains("scroll"), "scroll lock")
    }

    private static func fastScrollMomentum() {
        let g = engine()
        let a = [FingerSample(id: 1, point: CGPoint(x: 90, y: 80)), FingerSample(id: 2, point: CGPoint(x: 150, y: 80))]
        _ = g.ingest(samples: a, timestamp: 6, phase: .began, in: size)
        var y: CGFloat = 80
        var t = 6.0
        for _ in 0..<8 {
            y += 28
            t += 0.008
            _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 90, y: y)), FingerSample(id: 2, point: CGPoint(x: 150, y: y))], timestamp: t, phase: .moved, in: size)
        }
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 90, y: y)), FingerSample(id: 2, point: CGPoint(x: 150, y: y))], timestamp: t + 0.01, phase: .ended, in: size)
        let hasMomentum = ended.commands.contains { if case .scroll(_, _, let phase) = $0 { return phase == .momentumBegan } else { return false } }
        precondition(hasMomentum, "fast scroll momentum")
    }

    private static func frameRateIndependence() {
        // Test scroll momentum decay rate at simulated 60Hz and 120Hz
        let scrollEngine60 = ScrollGestureEngine()
        let scrollEngine120 = ScrollGestureEngine()

        let startPoints = [CGPoint(x: 100, y: 100), CGPoint(x: 150, y: 100)]
        _ = scrollEngine60.begin(points: startPoints, timestamp: 0)
        _ = scrollEngine120.begin(points: startPoints, timestamp: 0)

        // Inject initial movement
        let endPoints = [CGPoint(x: 100, y: 200), CGPoint(x: 150, y: 200)]
        _ = scrollEngine60.move(points: endPoints, timestamp: 0.05)
        _ = scrollEngine120.move(points: endPoints, timestamp: 0.05)

        _ = scrollEngine60.end(isTap: false)
        _ = scrollEngine120.end(isTap: false)

        precondition(scrollEngine60.isMomentumActive, "60Hz momentum began")
        precondition(scrollEngine120.isMomentumActive, "120Hz momentum began")

        // Tick 60Hz: 60 steps of 1/60s = 1.0s
        var distance60 = 0.0
        for _ in 0..<60 {
            let cmds = scrollEngine60.tickMomentum(dt: 1.0 / 60.0)
            for cmd in cmds {
                if case .scroll(_, let dy, _) = cmd { distance60 += abs(dy) }
            }
        }

        // Tick 120Hz: 120 steps of 1/120s = 1.0s
        var distance120 = 0.0
        for _ in 0..<120 {
            let cmds = scrollEngine120.tickMomentum(dt: 1.0 / 120.0)
            for cmd in cmds {
                if case .scroll(_, let dy, _) = cmd { distance120 += abs(dy) }
            }
        }

        // Total scroll distance over 1s must match within 8% between 60Hz and 120Hz
        let diff = abs(distance60 - distance120) / max(distance60, 1.0)
        precondition(diff < 0.08, "Frame rate independent physics test failed: 60Hz=\(distance60) vs 120Hz=\(distance120)")
    }

    private static func pinchDisabled() {
        let g = engine()
        let a = [FingerSample(id: 1, point: CGPoint(x: 140, y: 200)), FingerSample(id: 2, point: CGPoint(x: 180, y: 200))]
        _ = g.ingest(samples: a, timestamp: 7, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 80, y: 200)), FingerSample(id: 2, point: CGPoint(x: 260, y: 200))]
        let moved = g.ingest(samples: b, timestamp: 7.05, phase: .moved, in: size)
        let zoomed = moved.commands.contains { if case .zoom = $0 { return true } else { return false } }
        precondition(zoomed == false, "pinch must not zoom")
        precondition(moved.debug.scrollIntent != "pinch", "pinch intent disabled")
    }

    private static func horizontalThreeFingerSwipe() {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 80, y: 200)),
            FingerSample(id: 2, point: CGPoint(x: 120, y: 200)),
            FingerSample(id: 3, point: CGPoint(x: 160, y: 200))
        ]
        _ = g.ingest(samples: start, timestamp: 10, phase: .began, in: size)
        let swiped = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x + 40, y: $0.point.y)) }
        let locked = g.ingest(samples: swiped, timestamp: 10.06, phase: .moved, in: size)
        precondition(g.mode == .threeFingerSwipe, "horizontal three finger swipe locks")
        precondition(locked.commands.contains(.system(.previousDesktop)), "swipe right fires previous desktop")
        let left = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x - 40, y: $0.point.y)) }
        let g2 = engine()
        _ = g2.ingest(samples: start, timestamp: 11, phase: .began, in: size)
        let lockedLeft = g2.ingest(samples: left, timestamp: 11.06, phase: .moved, in: size)
        precondition(lockedLeft.commands.contains(.system(.nextDesktop)), "swipe left fires next desktop")
    }

    private static func fingerCountTransitions() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 8, phase: .began, in: size)
        precondition(g.mode == .tapCandidate || g.mode == .pointer)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.02, phase: .began, in: size)
        precondition(g.mode == .twoFingerCandidate || g.mode == .scrolling)
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.04, phase: .began, in: size)
        precondition(g.mode == .threeFingerCandidate)
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.05, phase: .ended, in: size)
        precondition(g.mode == .twoFingerCandidate || g.mode == .scrolling)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.06, phase: .ended, in: size)
        precondition(g.mode == .pointer || g.mode == .tapCandidate || g.mode == .dragging)
    }

    private static func asyncThreeFingerRelease() {
        // Physical scenario: 3 fingers swipe up, then lift sequentially (3 -> 2 -> 1 -> 0)
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 100, y: 200)),
            FingerSample(id: 2, point: CGPoint(x: 150, y: 200)),
            FingerSample(id: 3, point: CGPoint(x: 200, y: 200))
        ]
        _ = g.handle(changed: start, active: start, timestamp: 8.5, phase: .began, in: size)

        // Move up 40pt — swipe should lock and fire Mission Control immediately.
        let moved = [
            FingerSample(id: 1, point: CGPoint(x: 100, y: 160)),
            FingerSample(id: 2, point: CGPoint(x: 150, y: 160)),
            FingerSample(id: 3, point: CGPoint(x: 200, y: 160))
        ]
        let locked = g.handle(changed: moved, active: moved, timestamp: 8.58, phase: .moved, in: size)
        precondition(g.mode == .threeFingerSwipe, "mode must lock into threeFingerSwipe")
        precondition(locked.commands.contains(.system(.missionControl)), "Mission Control must fire when swipe locks")

        // Finger 1 lifts (remaining active: 2, 3)
        _ = g.handle(changed: [moved[0]], active: [moved[1], moved[2]], timestamp: 8.60, phase: .ended, in: size)
        precondition(g.mode == .threeFingerSwipe, "mode must STAY threeFingerSwipe after finger 1 lifts")

        // Finger 2 lifts (remaining active: 3)
        _ = g.handle(changed: [moved[1]], active: [moved[2]], timestamp: 8.61, phase: .ended, in: size)
        precondition(g.mode == .threeFingerSwipe, "mode must STAY threeFingerSwipe after finger 2 lifts")

        // Finger 3 lifts (remaining active: []) — must not double-fire
        let end3 = g.handle(changed: [moved[2]], active: [], timestamp: 8.62, phase: .ended, in: size)
        precondition(end3.commands.contains(.system(.missionControl)) == false, "must not double-fire Mission Control on lift")
    }

    private static func threeFingerCumulative() {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 80, y: 200)),
            FingerSample(id: 2, point: CGPoint(x: 120, y: 200)),
            FingerSample(id: 3, point: CGPoint(x: 160, y: 200))
        ]
        _ = g.ingest(samples: start, timestamp: 9, phase: .began, in: size)
        var x: CGFloat = 0
        var t = 9.0
        var output = GestureOutput()
        var sawSystem = false
        for delta in [4, 5, 4, 6, 5, 8, 7] as [CGFloat] {
            x += delta
            t += 0.008
            let samples = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x + x, y: $0.point.y)) }
            output = g.ingest(samples: samples, timestamp: t, phase: .moved, in: size)
            if output.commands.contains(where: { if case .system = $0 { return true } else { return false } }) {
                sawSystem = true
            }
        }
        precondition(output.debug.cumulativeX >= 32, "cumulative three-finger distance")
        precondition(sawSystem, "three finger swipe from cumulative frames")
    }

    private static func fourFinger() {
        let g = engine()
        let start = (1...4).map { FingerSample(id: $0, point: CGPoint(x: CGFloat(60 * $0), y: 180)) }
        _ = g.ingest(samples: start, timestamp: 10, phase: .began, in: size)
        var y: CGFloat = 0
        var t = 10.0
        var sawSystem = false
        for _ in 0..<10 {
            y += 6
            t += 0.008
            let out = g.ingest(samples: start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x, y: $0.point.y + y)) }, timestamp: t, phase: .moved, in: size)
            if out.commands.contains(where: { if case .system = $0 { return true } else { return false } }) {
                sawSystem = true
            }
        }
        precondition(sawSystem, "four finger swipe")
    }

    private static func animationFingerCounts() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 40, y: 40))], timestamp: 11, phase: .began, in: size)
        precondition(g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 41, y: 40))], timestamp: 11.01, phase: .moved, in: size).animation.fingerCount == 1)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 50))], timestamp: 11.02, phase: .began, in: size)
        precondition(g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 81, y: 50))], timestamp: 11.03, phase: .moved, in: size).animation.fingerCount == 2)
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 120, y: 60))], timestamp: 11.04, phase: .began, in: size)
        precondition(g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 121, y: 60))], timestamp: 11.05, phase: .moved, in: size).animation.fingerCount == 3)
        _ = g.ingest(samples: [FingerSample(id: 4, point: CGPoint(x: 160, y: 70))], timestamp: 11.06, phase: .began, in: size)
        precondition(g.ingest(samples: [FingerSample(id: 4, point: CGPoint(x: 161, y: 70))], timestamp: 11.07, phase: .moved, in: size).animation.fingerCount == 4)
        let lifted = g.ingest(samples: [
            FingerSample(id: 1, point: CGPoint(x: 41, y: 40)),
            FingerSample(id: 2, point: CGPoint(x: 81, y: 50)),
            FingerSample(id: 3, point: CGPoint(x: 121, y: 60)),
            FingerSample(id: 4, point: CGPoint(x: 161, y: 70))
        ], timestamp: 11.08, phase: .ended, in: size)
        precondition(lifted.animation.fingerCount == 0, "lift clears all orbs")
        precondition(lifted.animation.isFingerDown == false, "lift ends finger-down")
    }

    private static func liftClearsAnimation() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 40, y: 40))], timestamp: 12, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 42, y: 41))], timestamp: 12.04, phase: .ended, in: size)
        precondition(ended.animation.fingerCount == 0)
        precondition(ended.animation.isFingerDown == false)
        precondition(g.mode == .idle, "lift returns to idle")
    }

    private static func emptyMoveEndsGesture() {
        let g = engine()
        let sample = FingerSample(id: 1, point: CGPoint(x: 50, y: 50))
        _ = g.handle(changed: [sample], active: [sample], timestamp: 13, phase: .began, in: size)
        let out = g.handle(changed: [], active: [], timestamp: 13.02, phase: .moved, in: size)
        precondition(out.animation.isFingerDown == false, "empty active set ends the contact")
        precondition(g.mode == .idle)
    }
}
