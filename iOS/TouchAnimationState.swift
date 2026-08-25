import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#else
public enum UITouch {
    public enum Phase: Int {
        case began, moved, stationary, ended, cancelled, regionEntered, regionMoved, regionExited
    }
}
#endif

struct TouchAnimationFinger: Equatable, Identifiable {
    var id: Int
    var point: CGPoint
    var previousPoint: CGPoint = .zero
    var velocity: CGSize = .zero
    var phase: UITouch.Phase = .moved
}

struct TouchAnimationState: Equatable {
    var isConnected: Bool
    var fingerCount: Int
    var fingers: [TouchAnimationFinger]
    var points: [CGPoint] { fingers.map(\.point) }
    var velocity: CGSize
    var isFingerDown: Bool
    var isDragging: Bool
    var clickPulse: Int
    var doubleClickPulse: Int
    var trackpadSize: CGSize
    var modeName: String
    var isPrecision: Bool
    var scrollIntent: String
    var gestureProgress: CGSize
    var lockedAction: SystemAction?

    static let idle = TouchAnimationState(
        isConnected: false,
        fingerCount: 0,
        fingers: [],
        velocity: .zero,
        isFingerDown: false,
        isDragging: false,
        clickPulse: 0,
        doubleClickPulse: 0,
        trackpadSize: CGSize(width: 390, height: 640),
        modeName: "idle",
        isPrecision: false,
        scrollIntent: "none",
        gestureProgress: .zero,
        lockedAction: nil
    )
}
