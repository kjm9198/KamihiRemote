import CoreGraphics
import Foundation
import Carbon.HIToolbox

protocol GamepadOutput {
    func apply(_ state: ControllerState)
    func reset()
}

final class KeyboardGamepadOutput: GamepadOutput {
    var mapping: ControllerMapping = .mac
    private var last = ControllerState.neutral
    private var heldKeys = Set<UInt16>()

    func apply(_ state: ControllerState) {
        // Buttons
        applyAction(mapping.a, down: state.isDown(.a), wasDown: last.isDown(.a))
        applyAction(mapping.b, down: state.isDown(.b), wasDown: last.isDown(.b))
        applyAction(mapping.x, down: state.isDown(.x), wasDown: last.isDown(.x))
        applyAction(mapping.y, down: state.isDown(.y), wasDown: last.isDown(.y))
        applyAction(mapping.l1, down: state.isDown(.l1), wasDown: last.isDown(.l1))
        applyAction(mapping.r1, down: state.isDown(.r1), wasDown: last.isDown(.r1))
        applyAction(mapping.l2, down: state.leftTrigger > 0.4, wasDown: last.leftTrigger > 0.4)
        applyAction(mapping.r2, down: state.rightTrigger > 0.4, wasDown: last.rightTrigger > 0.4)
        applyAction(mapping.start, down: state.isDown(.start), wasDown: last.isDown(.start))
        applyAction(mapping.menu, down: state.isDown(.menu), wasDown: last.isDown(.menu))
        applyAction(mapping.view, down: state.isDown(.view), wasDown: last.isDown(.view))
        applyAction(mapping.l3, down: state.isDown(.l3), wasDown: last.isDown(.l3))
        applyAction(mapping.r3, down: state.isDown(.r3), wasDown: last.isDown(.r3))

        // D-Pad
        let dpad = DPadDirection(rawValue: state.dpad) ?? .none
        let lastDpad = DPadDirection(rawValue: last.dpad) ?? .none
        let up = dpad == .up || dpad == .upLeft || dpad == .upRight
        let down = dpad == .down || dpad == .downLeft || dpad == .downRight
        let left = dpad == .left || dpad == .upLeft || dpad == .downLeft
        let right = dpad == .right || dpad == .upRight || dpad == .downRight

        let lastUp = lastDpad == .up || lastDpad == .upLeft || lastDpad == .upRight
        let lastDown = lastDpad == .down || lastDpad == .downLeft || lastDpad == .downRight
        let lastLeft = lastDpad == .left || lastDpad == .upLeft || lastDpad == .downLeft
        let lastRight = lastDpad == .right || lastDpad == .upRight || lastDpad == .downRight

        applyAction(mapping.dpadUp, down: up, wasDown: lastUp)
        applyAction(mapping.dpadDown, down: down, wasDown: lastDown)
        applyAction(mapping.dpadLeft, down: left, wasDown: lastLeft)
        applyAction(mapping.dpadRight, down: right, wasDown: lastRight)

        // Analog Sticks
        applyStick(mapping.leftStick, x: Double(state.leftX), y: Double(state.leftY))
        applyStick(mapping.rightStick, x: Double(state.rightX), y: Double(state.rightY))

        last = state
    }

    func reset() {
        for key in heldKeys {
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
        heldKeys.removeAll()
        last = .neutral
    }

    private func applyAction(_ action: ControllerAction, down: Bool, wasDown: Bool) {
        guard down != wasDown else { return }
        switch action {
        case .none:
            break
        case .key(let code, _):
            if down {
                heldKeys.insert(code)
                _ = InputEngine.keyDown(code: code, flags: 0)
            } else {
                heldKeys.remove(code)
                _ = InputEngine.keyUp(code: code, flags: 0)
            }
        case .shortcut(let spec, _):
            if down {
                _ = InputEngine.shortcut(spec)
            }
        case .click:
            if down {
                _ = InputEngine.mouseDown()
            } else {
                _ = InputEngine.mouseUp()
            }
        case .rightClick:
            if down {
                _ = InputEngine.rightClick()
            }
        case .system(let sys):
            if down {
                _ = InputEngine.perform(sys)
            }
        case .media(let med):
            if down {
                _ = InputEngine.media(med)
            }
        case .presentation(let pres):
            if down {
                _ = InputEngine.presentation(pres)
            }
        case .openApp(let bundleID, _):
            if down {
                Task {
                    _ = await AppCatalog.open(bundleIdentifier: bundleID)
                }
            }
        case .openURL(let url, _):
            if down {
                _ = InputEngine.openURL(url)
            }
        }
    }

    private func applyStick(_ action: StickAction, x: Double, y: Double) {
        switch action {
        case .wasd:
            digital(y < -0.28, key: CGKeyCode(kVK_ANSI_W))
            digital(y > 0.28, key: CGKeyCode(kVK_ANSI_S))
            digital(x < -0.28, key: CGKeyCode(kVK_ANSI_A))
            digital(x > 0.28, key: CGKeyCode(kVK_ANSI_D))
        case .arrows:
            digital(y < -0.28, key: CGKeyCode(kVK_UpArrow))
            digital(y > 0.28, key: CGKeyCode(kVK_DownArrow))
            digital(x < -0.28, key: CGKeyCode(kVK_LeftArrow))
            digital(x > 0.28, key: CGKeyCode(kVK_RightArrow))
        case .mouse:
            let dx = x * 14.0
            let dy = y * 14.0
            if hypot(dx, dy) > 0.2 {
                _ = InputEngine.move(dx: dx, dy: dy)
            }
        case .scroll:
            let dx = x * 10.0
            let dy = -y * 10.0
            if hypot(dx, dy) > 0.2 {
                _ = InputEngine.scroll(dx: dx, dy: dy, phase: .changed)
            }
        case .none:
            break
        }
    }

    private func digital(_ down: Bool, key: CGKeyCode) {
        if down {
            if heldKeys.contains(key) == false {
                heldKeys.insert(key)
                _ = InputEngine.keyDown(code: key, flags: 0)
            }
        } else if heldKeys.contains(key) {
            heldKeys.remove(key)
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
    }
}

enum KeyboardGamepad {
    static let shared = KeyboardGamepadOutput()
}
