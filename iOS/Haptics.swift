import UIKit

enum Haptics {
    private static let clickGen = UIImpactFeedbackGenerator(style: .medium)
    private static let pressGen = UIImpactFeedbackGenerator(style: .light)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)

    static func prepare() {
        clickGen.prepare()
        pressGen.prepare()
        softGen.prepare()
    }

    static func click() {
        clickGen.impactOccurred(intensity: 0.9)
        clickGen.prepare()
    }

    static func mouseDown() {
        pressGen.impactOccurred(intensity: 0.7)
        pressGen.prepare()
    }

    static func rightClick() {
        clickGen.impactOccurred(intensity: 1.0)
        clickGen.prepare()
    }

    static func connect() {
        softGen.impactOccurred(intensity: 0.5)
        softGen.prepare()
    }
}
