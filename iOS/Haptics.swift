import Foundation
#if canImport(UIKit)
import UIKit

enum Haptics {
    private static let clickGen = UIImpactFeedbackGenerator(style: .medium)
    private static let pressGen = UIImpactFeedbackGenerator(style: .light)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)

    static var level: HapticLevel = .normal

    static func prepare() {
        guard level != .off else { return }
        clickGen.prepare()
        pressGen.prepare()
        softGen.prepare()
    }

    static func click() { play(clickGen, 0.9) }
    static func mouseDown() { play(pressGen, 0.7) }
    static func rightClick() { play(clickGen, 1.0) }
    static func dragEnd() { play(softGen, 0.45) }
    static func gesture() { play(pressGen, 0.8) }
    static func connect() { play(softGen, 0.5) }
    static func slideChange() { play(clickGen, 0.55) }

    private static func play(_ generator: UIImpactFeedbackGenerator, _ intensity: CGFloat) {
        guard level != .off else { return }
        let scaled = level == .light ? intensity * 0.55 : intensity
        generator.impactOccurred(intensity: scaled)
        generator.prepare()
    }
}
#else
enum Haptics {
    static var level: HapticLevel = .normal
    static func prepare() {}
    static func click() {}
    static func mouseDown() {}
    static func rightClick() {}
    static func dragEnd() {}
    static func gesture() {}
    static func connect() {}
    static func slideChange() {}
}
#endif
