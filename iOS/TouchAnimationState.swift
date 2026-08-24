import CoreGraphics
import Foundation

struct TouchAnimationState: Equatable {
    var isConnected: Bool
    var fingerCount: Int
    var points: [CGPoint]
    var velocity: CGSize
    var isFingerDown: Bool
    var isDragging: Bool
    var clickPulse: Int
    var doubleClickPulse: Int
    var trackpadSize: CGSize

    static let idle = TouchAnimationState(
        isConnected: false,
        fingerCount: 0,
        points: [],
        velocity: .zero,
        isFingerDown: false,
        isDragging: false,
        clickPulse: 0,
        doubleClickPulse: 0,
        trackpadSize: CGSize(width: 390, height: 640)
    )
}
