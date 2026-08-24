import AppKit
import ApplicationServices
import CoreGraphics

enum InputEngine {
    private static var mouseIsDown = false
    private static let source = CGEventSource(stateID: .hidSystemState)

    static var canInjectEvents: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func move(dx: Double, dy: Double) -> Bool {
        guard canInjectEvents else { return false }
        let current = CGEvent(source: nil)?.location ?? .zero
        let next = clamp(CGPoint(x: current.x + dx, y: current.y + dy))
        let type: CGEventType = mouseIsDown ? .leftMouseDragged : .mouseMoved
        return postMouse(type: type, at: next, button: .left)
    }

    @discardableResult
    static func click() -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        let down = postMouse(type: .leftMouseDown, at: point, button: .left)
        let up = postMouse(type: .leftMouseUp, at: point, button: .left)
        mouseIsDown = false
        return down && up
    }

    @discardableResult
    static func rightClick() -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        let down = postMouse(type: .rightMouseDown, at: point, button: .right)
        let up = postMouse(type: .rightMouseUp, at: point, button: .right)
        return down && up
    }

    @discardableResult
    static func mouseDown() -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        mouseIsDown = true
        return postMouse(type: .leftMouseDown, at: point, button: .left)
    }

    @discardableResult
    static func mouseUp() -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        mouseIsDown = false
        return postMouse(type: .leftMouseUp, at: point, button: .left)
    }

    @discardableResult
    static func scroll(dx: Double, dy: Double) -> Bool {
        guard canInjectEvents else { return false }
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32((-dy).rounded()),
            wheel2: Int32((-dx).rounded()),
            wheel3: 0
        ) else { return false }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -dy)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -dx)
        event.post(tap: .cghidEventTap)
        return true
    }

    static func testNudge(dx: Double = 100) -> (created: Bool, posted: Bool, trusted: Bool, from: CGPoint, to: CGPoint) {
        let trusted = canInjectEvents
        let current = CGEvent(source: nil)?.location ?? .zero
        let target = clamp(CGPoint(x: current.x + dx, y: current.y))
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else {
            return (false, false, trusted, current, target)
        }
        event.post(tap: .cghidEventTap)
        return (true, true, trusted, current, target)
    }

    private static func postMouse(type: CGEventType, at point: CGPoint, button: CGMouseButton) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func clamp(_ point: CGPoint) -> CGPoint {
        let frames = NSScreen.screens.map(quartzFrame)
        guard let first = frames.first else { return point }
        let union = frames.dropFirst().reduce(first, { $0.union($1) })
        return CGPoint(
            x: min(max(point.x, union.minX), union.maxX - 1),
            y: min(max(point.y, union.minY), union.maxY - 1)
        )
    }

    private static func quartzFrame(_ screen: NSScreen) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let frame = screen.frame
        return CGRect(
            x: frame.origin.x,
            y: mainHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }
}
