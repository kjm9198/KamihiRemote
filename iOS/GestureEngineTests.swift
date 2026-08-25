import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GestureEngineTests {
    private static let size = CGSize(width: 390, height: 640)

    @discardableResult
    static func runSelfChecks() -> Bool {
        do {
            try check("oneFingerMove", oneFingerMove)
            try check("oneFingerTap", oneFingerTap)
            try check("doubleClick", doubleClick)
            try check("twoFingerTap", twoFingerTap)
            try check("threeFingerTap", threeFingerTap)
            try check("slowScroll", slowScroll)
            try check("fastScrollMomentum", fastScrollMomentum)
            try check("frameRateIndependence", frameRateIndependence)
            try check("horizontalThreeFingerSwipe", horizontalThreeFingerSwipe)
            try check("pinchDisabled", pinchDisabled)
            try check("pinchEnabled", pinchEnabled)
            try check("twoFingerSticky", twoFingerSticky)
            try check("fingerCountTransitions", fingerCountTransitions)
            try check("asyncThreeFingerRelease", asyncThreeFingerRelease)
            try check("threeFingerCumulative", threeFingerCumulative)
            try check("fourFinger", fourFinger)
            try check("animationFingerCounts", animationFingerCounts)
            try check("liftClearsAnimation", liftClearsAnimation)
            try check("emptyMoveEndsGesture", emptyMoveEndsGesture)
            NSLog("Kamihi gesture self-checks passed")
            return true
        } catch {
            // Never crash the shipping DEBUG app for a unit-check mismatch.
            NSLog("Kamihi gesture self-check FAILED: %@", String(describing: error))
            return false
        }
    }

    private struct CheckError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    private static func check(_ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
        } catch {
            throw CheckError(message: "\(name): \(error)")
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw CheckError(message: message)
        }
    }

    private static func engine(tapToClick: Bool = true) -> GestureEngine {
        let engine = GestureEngine()
        engine.preferences.tapToClick = tapToClick
        engine.preferences.twoFingerSecondaryClick = true
        engine.preferences.scrollFeel = .macLike
        engine.preferences.pinchEnabled = true
        return engine
    }

    private static func defaultEngine() -> GestureEngine {
        let engine = GestureEngine()
        return engine
    }

    private static func oneFingerMove() throws {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 1, phase: .began, in: size)
        let moved = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 130, y: 108))], timestamp: 1.03, phase: .moved, in: size)
        try require(moved.commands.contains { if case .move(let dx, _) = $0 { return dx > 0 } else { return false } }, "one finger move")
    }

    private static func oneFingerTap() throws {
        let g = engine(tapToClick: true)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.08, phase: .ended, in: size)
        try require(ended.commands.contains(.click), "tap to click when enabled")
        let g2 = engine(tapToClick: false)
        _ = g2.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2, phase: .began, in: size)
        let noClick = g2.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.08, phase: .ended, in: size)
        try require(noClick.commands.contains(.click) == false, "single tap must not click when disabled")
        let g3 = defaultEngine()
        try require(g3.preferences.tapToClick == true, "tap to click on by default")
        _ = g3.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2.2, phase: .began, in: size)
        let defaultClick = g3.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.28, phase: .ended, in: size)
        try require(defaultClick.commands.contains(.click), "default preferences click on tap")
    }

    private static func doubleClick() throws {
        let g = engine(tapToClick: true)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 3, phase: .began, in: size)
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 3.05, phase: .ended, in: size)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 80))], timestamp: 3.12, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 80))], timestamp: 3.18, phase: .ended, in: size)
        try require(ended.commands.contains(.doubleClick), "double click")
    }

    private static func twoFingerTap() throws {
        let g = engine()
        let start = [FingerSample(id: 1, point: CGPoint(x: 90, y: 90)), FingerSample(id: 2, point: CGPoint(x: 140, y: 90))]
        _ = g.ingest(samples: start, timestamp: 4, phase: .began, in: size)
        let ended = g.ingest(samples: start, timestamp: 4.08, phase: .ended, in: size)
        try require(ended.commands.contains(.rightClick), "two finger tap")
    }

    private static func threeFingerTap() throws {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 80, y: 90)),
            FingerSample(id: 2, point: CGPoint(x: 130, y: 90)),
            FingerSample(id: 3, point: CGPoint(x: 180, y: 90))
        ]
        _ = g.ingest(samples: start, timestamp: 4.5, phase: .began, in: size)
        let ended = g.ingest(samples: start, timestamp: 4.58, phase: .ended, in: size)
        try require(ended.commands.contains(.shortcut("cmd+ctrl+d")), "three finger tap for Look Up")
    }

    private static func slowScroll() throws {
        let g = engine()
        let a = [FingerSample(id: 1, point: CGPoint(x: 90, y: 120)), FingerSample(id: 2, point: CGPoint(x: 150, y: 120))]
        _ = g.ingest(samples: a, timestamp: 5, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 90, y: 180)), FingerSample(id: 2, point: CGPoint(x: 150, y: 180))]
        let moved = g.ingest(samples: b, timestamp: 5.08, phase: .moved, in: size)
        try require(moved.commands.contains { if case .scroll = $0 { return true } else { return false } }, "slow scroll")
        try require(moved.debug.scrollIntent == "scroll" || moved.debug.mode.contains("scroll"), "scroll lock")
    }

    private static func fastScrollMomentum() throws {
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
        try require(hasMomentum, "fast scroll momentum")
    }

    private static func frameRateIndependence() throws {
        let scrollEngine60 = ScrollGestureEngine()
        let scrollEngine120 = ScrollGestureEngine()

        let startPoints = [CGPoint(x: 100, y: 100), CGPoint(x: 150, y: 100)]
        _ = scrollEngine60.begin(points: startPoints, timestamp: 0)
        _ = scrollEngine120.begin(points: startPoints, timestamp: 0)

        let endPoints = [CGPoint(x: 100, y: 200), CGPoint(x: 150, y: 200)]
        _ = scrollEngine60.move(points: endPoints, timestamp: 0.05)
        _ = scrollEngine120.move(points: endPoints, timestamp: 0.05)

        _ = scrollEngine60.end(isTap: false)
        _ = scrollEngine120.end(isTap: false)

        try require(scrollEngine60.isMomentumActive, "60Hz momentum began")
        try require(scrollEngine120.isMomentumActive, "120Hz momentum began")

        var distance60 = 0.0
        for _ in 0..<60 {
            let cmds = scrollEngine60.tickMomentum(dt: 1.0 / 60.0)
            for cmd in cmds {
                if case .scroll(_, let dy, _) = cmd { distance60 += abs(dy) }
            }
        }

        var distance120 = 0.0
        for _ in 0..<120 {
            let cmds = scrollEngine120.tickMomentum(dt: 1.0 / 120.0)
            for cmd in cmds {
                if case .scroll(_, let dy, _) = cmd { distance120 += abs(dy) }
            }
        }

        let diff = abs(distance60 - distance120) / max(distance60, 1.0)
        try require(diff < 0.08, "Frame rate independent physics test failed: 60Hz=\(distance60) vs 120Hz=\(distance120)")
    }

    private static func pinchDisabled() throws {
        let g = engine()
        g.preferences.pinchEnabled = false
        let a = [FingerSample(id: 1, point: CGPoint(x: 140, y: 200)), FingerSample(id: 2, point: CGPoint(x: 180, y: 200))]
        _ = g.ingest(samples: a, timestamp: 7, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 80, y: 200)), FingerSample(id: 2, point: CGPoint(x: 260, y: 200))]
        let moved = g.ingest(samples: b, timestamp: 7.05, phase: .moved, in: size)
        let zoomed = moved.commands.contains { if case .zoom = $0 { return true } else { return false } }
        try require(zoomed == false, "pinch must not zoom when disabled")
    }

    private static func pinchEnabled() throws {
        let g = engine()
        g.preferences.pinchEnabled = true
        g.preferences.pinchThreshold = 0.08
        let a = [FingerSample(id: 1, point: CGPoint(x: 140, y: 200)), FingerSample(id: 2, point: CGPoint(x: 180, y: 200))]
        _ = g.ingest(samples: a, timestamp: 7.2, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 80, y: 200)), FingerSample(id: 2, point: CGPoint(x: 260, y: 200))]
        let moved = g.ingest(samples: b, timestamp: 7.28, phase: .moved, in: size)
        let zoomed = moved.commands.contains { if case .zoom = $0 { return true } else { return false } }
        try require(zoomed, "pinch must zoom when enabled")
    }

    private static func horizontalThreeFingerSwipe() throws {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 80, y: 200)),
            FingerSample(id: 2, point: CGPoint(x: 120, y: 200)),
            FingerSample(id: 3, point: CGPoint(x: 160, y: 200))
        ]
        _ = g.ingest(samples: start, timestamp: 10, phase: .began, in: size)
        let swiped = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x + 40, y: $0.point.y)) }
        let locked = g.ingest(samples: swiped, timestamp: 10.06, phase: .moved, in: size)
        try require(g.mode == .threeFingerSwipe, "horizontal three finger swipe locks")
        try require(locked.commands.contains(.system(.nextDesktop)), "swipe right fires next desktop")
        let left = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x - 40, y: $0.point.y)) }
        let g2 = engine()
        _ = g2.ingest(samples: start, timestamp: 11, phase: .began, in: size)
        let lockedLeft = g2.ingest(samples: left, timestamp: 11.06, phase: .moved, in: size)
        try require(lockedLeft.commands.contains(.system(.previousDesktop)), "swipe left fires previous desktop")
    }

    private static func twoFingerSticky() throws {
        let g = engine()
        let start = [FingerSample(id: 1, point: CGPoint(x: 90, y: 120)), FingerSample(id: 2, point: CGPoint(x: 150, y: 120))]
        _ = g.ingest(samples: start, timestamp: 14, phase: .began, in: size)
        let moved = [FingerSample(id: 1, point: CGPoint(x: 90, y: 180)), FingerSample(id: 2, point: CGPoint(x: 150, y: 180))]
        _ = g.ingest(samples: moved, timestamp: 14.05, phase: .moved, in: size)
        try require(g.mode == .scrolling || g.mode == .twoFingerCandidate, "scroll should commit")
        _ = g.handle(changed: [moved[0]], active: [moved[1]], timestamp: 14.06, phase: .ended, in: size)
        try require(g.mode == .scrolling || g.mode == .pinching, "2→1 must not become pointer while scroll committed")
        let out = g.handle(changed: [moved[1]], active: [], timestamp: 14.07, phase: .ended, in: size)
        try require(out.commands.contains { if case .move = $0 { return true } else { return false } } == false, "sticky scroll must not emit MOVE")
    }

    private static func fingerCountTransitions() throws {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 8, phase: .began, in: size)
        try require(g.mode == .tapCandidate || g.mode == .pointer, "1 finger start")
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.02, phase: .began, in: size)
        try require(g.mode == .twoFingerCandidate || g.mode == .scrolling, "2 finger")
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.04, phase: .began, in: size)
        try require(g.mode == .threeFingerCandidate, "3 finger")
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.05, phase: .ended, in: size)
        try require(g.mode == .twoFingerCandidate || g.mode == .scrolling || g.mode == .threeFingerCandidate, "3→2")
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.06, phase: .ended, in: size)
        try require(
            g.mode == .pointer || g.mode == .tapCandidate || g.mode == .dragging || g.mode == .twoFingerCandidate || g.mode == .threeFingerCandidate,
            "2→1 settles without crash"
        )
    }

    private static func asyncThreeFingerRelease() throws {
        let g = engine()
        let start = [
            FingerSample(id: 1, point: CGPoint(x: 100, y: 200)),
            FingerSample(id: 2, point: CGPoint(x: 150, y: 200)),
            FingerSample(id: 3, point: CGPoint(x: 200, y: 200))
        ]
        _ = g.handle(changed: start, active: start, timestamp: 8.5, phase: .began, in: size)

        let moved = [
            FingerSample(id: 1, point: CGPoint(x: 100, y: 160)),
            FingerSample(id: 2, point: CGPoint(x: 150, y: 160)),
            FingerSample(id: 3, point: CGPoint(x: 200, y: 160))
        ]
        let locked = g.handle(changed: moved, active: moved, timestamp: 8.58, phase: .moved, in: size)
        try require(g.mode == .threeFingerSwipe, "mode must lock into threeFingerSwipe")
        try require(locked.commands.contains(.system(.missionControl)), "Mission Control must fire when swipe locks")

        _ = g.handle(changed: [moved[0]], active: [moved[1], moved[2]], timestamp: 8.60, phase: .ended, in: size)
        try require(g.mode == .threeFingerSwipe, "mode must STAY threeFingerSwipe after finger 1 lifts")

        _ = g.handle(changed: [moved[1]], active: [moved[2]], timestamp: 8.61, phase: .ended, in: size)
        try require(g.mode == .threeFingerSwipe, "mode must STAY threeFingerSwipe after finger 2 lifts")

        let end3 = g.handle(changed: [moved[2]], active: [], timestamp: 8.62, phase: .ended, in: size)
        try require(end3.commands.contains(.system(.missionControl)) == false, "must not double-fire Mission Control on lift")
    }

    private static func threeFingerCumulative() throws {
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
        try require(output.debug.cumulativeX >= 32, "cumulative three-finger distance")
        try require(sawSystem, "three finger swipe from cumulative frames")
    }

    private static func fourFinger() throws {
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
        try require(sawSystem, "four finger swipe")
    }

    private static func animationFingerCounts() throws {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 40, y: 40))], timestamp: 11, phase: .began, in: size)
        try require(g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 41, y: 40))], timestamp: 11.01, phase: .moved, in: size).animation.fingerCount == 1, "1 orb")
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 80, y: 50))], timestamp: 11.02, phase: .began, in: size)
        try require(g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 81, y: 50))], timestamp: 11.03, phase: .moved, in: size).animation.fingerCount == 2, "2 orbs")
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 120, y: 60))], timestamp: 11.04, phase: .began, in: size)
        try require(g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 121, y: 60))], timestamp: 11.05, phase: .moved, in: size).animation.fingerCount == 3, "3 orbs")
        _ = g.ingest(samples: [FingerSample(id: 4, point: CGPoint(x: 160, y: 70))], timestamp: 11.06, phase: .began, in: size)
        try require(g.ingest(samples: [FingerSample(id: 4, point: CGPoint(x: 161, y: 70))], timestamp: 11.07, phase: .moved, in: size).animation.fingerCount == 4, "4 orbs")
        let lifted = g.ingest(samples: [
            FingerSample(id: 1, point: CGPoint(x: 41, y: 40)),
            FingerSample(id: 2, point: CGPoint(x: 81, y: 50)),
            FingerSample(id: 3, point: CGPoint(x: 121, y: 60)),
            FingerSample(id: 4, point: CGPoint(x: 161, y: 70))
        ], timestamp: 11.08, phase: .ended, in: size)
        try require(lifted.animation.fingerCount == 0, "lift clears all orbs")
        try require(lifted.animation.isFingerDown == false, "lift ends finger-down")
    }

    private static func liftClearsAnimation() throws {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 40, y: 40))], timestamp: 12, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 42, y: 41))], timestamp: 12.04, phase: .ended, in: size)
        try require(ended.animation.fingerCount == 0, "clear count")
        try require(ended.animation.isFingerDown == false, "clear down")
        try require(g.mode == .idle, "lift returns to idle")
    }

    private static func emptyMoveEndsGesture() throws {
        let g = engine()
        let sample = FingerSample(id: 1, point: CGPoint(x: 50, y: 50))
        _ = g.handle(changed: [sample], active: [sample], timestamp: 13, phase: .began, in: size)
        let out = g.handle(changed: [], active: [], timestamp: 13.02, phase: .moved, in: size)
        try require(out.animation.isFingerDown == false, "empty active set ends the contact")
        try require(g.mode == .idle, "idle after empty move")
    }
}
