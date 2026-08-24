import CoreGraphics
import Foundation
import UIKit

enum GestureEngineTests {
    private static let size = CGSize(width: 390, height: 640)

    @discardableResult
    static func runSelfChecks() -> Bool {
        oneFingerMove()
        oneFingerTap()
        doubleClick()
        twoFingerTap()
        slowScroll()
        fastScrollMomentum()
        pinchLock()
        fingerCountTransitions()
        threeFingerCumulative()
        fourFinger()
        animationFingerCounts()
        NSLog("Kamihi gesture self-checks passed")
        return true
    }

    private static func engine() -> GestureEngine {
        let engine = GestureEngine()
        engine.preferences.tapToClick = true
        engine.preferences.twoFingerSecondaryClick = true
        engine.preferences.scrollFeel = .macLike
        return engine
    }

    private static func oneFingerMove() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 1, phase: .began, in: size)
        let moved = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 130, y: 108))], timestamp: 1.03, phase: .moved, in: size)
        precondition(moved.commands.contains { if case .move(let dx, _) = $0 { return dx > 0 } else { return false } }, "one finger move")
    }

    private static func oneFingerTap() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 80, y: 80))], timestamp: 2, phase: .began, in: size)
        let ended = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 81, y: 80))], timestamp: 2.08, phase: .ended, in: size)
        precondition(ended.commands.contains(.click), "tap to click")
    }

    private static func doubleClick() {
        let g = engine()
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

    private static func pinchLock() {
        let g = engine()
        let a = [FingerSample(id: 1, point: CGPoint(x: 140, y: 200)), FingerSample(id: 2, point: CGPoint(x: 180, y: 200))]
        _ = g.ingest(samples: a, timestamp: 7, phase: .began, in: size)
        let b = [FingerSample(id: 1, point: CGPoint(x: 80, y: 200)), FingerSample(id: 2, point: CGPoint(x: 260, y: 200))]
        let moved = g.ingest(samples: b, timestamp: 7.05, phase: .moved, in: size)
        let zoomed = moved.commands.contains { if case .zoom = $0 { return true } else { return false } }
        precondition(zoomed || moved.debug.scrollIntent == "pinch" || moved.debug.mode == "pinching", "pinch lock")
    }

    private static func fingerCountTransitions() {
        let g = engine()
        _ = g.ingest(samples: [FingerSample(id: 1, point: CGPoint(x: 100, y: 100))], timestamp: 8, phase: .began, in: size)
        precondition(g.mode == .tapCandidate || g.mode == .pointer)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.02, phase: .began, in: size)
        precondition(g.mode == .twoFingerCandidate || g.mode == .scrolling || g.mode == .pinching)
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.04, phase: .began, in: size)
        precondition(g.mode == .threeFingerCandidate)
        _ = g.ingest(samples: [FingerSample(id: 3, point: CGPoint(x: 180, y: 120))], timestamp: 8.05, phase: .ended, in: size)
        precondition(g.mode == .twoFingerCandidate || g.mode == .scrolling || g.mode == .pinching)
        _ = g.ingest(samples: [FingerSample(id: 2, point: CGPoint(x: 140, y: 110))], timestamp: 8.06, phase: .ended, in: size)
        precondition(g.mode == .pointer || g.mode == .tapCandidate || g.mode == .dragging)
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
        for delta in [4, 5, 4, 6, 5, 8, 7] as [CGFloat] {
            x += delta
            t += 0.008
            let samples = start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x + x, y: $0.point.y)) }
            output = g.ingest(samples: samples, timestamp: t, phase: .moved, in: size)
        }
        precondition(output.debug.cumulativeX >= 32, "cumulative three-finger distance")
        let ended = g.ingest(samples: start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x + x, y: $0.point.y)) }, timestamp: t + 0.01, phase: .ended, in: size)
        precondition(ended.commands.contains { if case .system(let action) = $0 { return action == .nextDesktop || action == .previousDesktop } else { return false } }, "three finger swipe")
    }

    private static func fourFinger() {
        let g = engine()
        let start = (1...4).map { FingerSample(id: $0, point: CGPoint(x: CGFloat(60 * $0), y: 180)) }
        _ = g.ingest(samples: start, timestamp: 10, phase: .began, in: size)
        var y: CGFloat = 0
        var t = 10.0
        for _ in 0..<10 {
            y += 6
            t += 0.008
            _ = g.ingest(samples: start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x, y: $0.point.y + y)) }, timestamp: t, phase: .moved, in: size)
        }
        let ended = g.ingest(samples: start.map { FingerSample(id: $0.id, point: CGPoint(x: $0.point.x, y: $0.point.y + y)) }, timestamp: t + 0.01, phase: .ended, in: size)
        precondition(ended.commands.contains { if case .system = $0 { return true } else { return false } }, "four finger swipe")
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
    }
}
