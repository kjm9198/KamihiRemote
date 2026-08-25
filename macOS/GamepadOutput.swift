import CoreGraphics
import Foundation
import Carbon.HIToolbox

protocol GamepadOutput {
    func apply(_ state: ControllerState)
    func reset()
}

final class KeyboardGamepadOutput: GamepadOutput {
    var mapping: ControllerMapping = .gaming {
        didSet {
            if oldValue != mapping {
                reset()
            }
        }
    }

    private var last = ControllerState.neutral
    private var heldKeyOwners: [UInt16: Set<String>] = [:]

    func apply(_ state: ControllerState) {
        // Buttons. Each physical control owns its keyboard hold independently so
        // multiple controls can safely map to the same key.
        applyAction(mapping.a, owner: "button.a", down: state.isDown(.a), wasDown: last.isDown(.a))
        applyAction(mapping.b, owner: "button.b", down: state.isDown(.b), wasDown: last.isDown(.b))
        applyAction(mapping.x, owner: "button.x", down: state.isDown(.x), wasDown: last.isDown(.x))
        applyAction(mapping.y, owner: "button.y", down: state.isDown(.y), wasDown: last.isDown(.y))
        applyAction(mapping.l1, owner: "button.l1", down: state.isDown(.l1), wasDown: last.isDown(.l1))
        applyAction(mapping.r1, owner: "button.r1", down: state.isDown(.r1), wasDown: last.isDown(.r1))
        applyAction(mapping.l2, owner: "trigger.l2", down: state.leftTrigger > 0.4, wasDown: last.leftTrigger > 0.4)
        applyAction(mapping.r2, owner: "trigger.r2", down: state.rightTrigger > 0.4, wasDown: last.rightTrigger > 0.4)
        applyAction(mapping.start, owner: "button.start", down: state.isDown(.start), wasDown: last.isDown(.start))
        applyAction(mapping.menu, owner: "button.menu", down: state.isDown(.menu), wasDown: last.isDown(.menu))
        applyAction(mapping.view, owner: "button.view", down: state.isDown(.view), wasDown: last.isDown(.view))
        applyAction(mapping.l3, owner: "button.l3", down: state.isDown(.l3), wasDown: last.isDown(.l3))
        applyAction(mapping.r3, owner: "button.r3", down: state.isDown(.r3), wasDown: last.isDown(.r3))

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

        applyAction(mapping.dpadUp, owner: "dpad.up", down: up, wasDown: lastUp)
        applyAction(mapping.dpadDown, owner: "dpad.down", down: down, wasDown: lastDown)
        applyAction(mapping.dpadLeft, owner: "dpad.left", down: left, wasDown: lastLeft)
        applyAction(mapping.dpadRight, owner: "dpad.right", down: right, wasDown: lastRight)

        // Analog Sticks
        applyStick(mapping.leftStick, owner: "stick.left", x: Double(state.leftX), y: Double(state.leftY))
        applyStick(mapping.rightStick, owner: "stick.right", x: Double(state.rightX), y: Double(state.rightY))

        last = state
    }

    func reset() {
        for key in heldKeyOwners.keys {
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
        heldKeyOwners.removeAll()
        last = .neutral
    }

    private func applyAction(_ action: ControllerAction, owner: String, down: Bool, wasDown: Bool) {
        guard down != wasDown else { return }
        switch action {
        case .none:
            break
        case .key(let code, _):
            setKeyOwner(owner, key: code, down: down)
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

    private func applyStick(_ action: StickAction, owner: String, x: Double, y: Double) {
        switch action {
        case .wasd:
            digital(y < -0.22, key: CGKeyCode(kVK_ANSI_W), owner: "\(owner).up")
            digital(y > 0.22, key: CGKeyCode(kVK_ANSI_S), owner: "\(owner).down")
            digital(x < -0.22, key: CGKeyCode(kVK_ANSI_A), owner: "\(owner).left")
            digital(x > 0.22, key: CGKeyCode(kVK_ANSI_D), owner: "\(owner).right")
        case .arrows:
            digital(y < -0.22, key: CGKeyCode(kVK_UpArrow), owner: "\(owner).up")
            digital(y > 0.22, key: CGKeyCode(kVK_DownArrow), owner: "\(owner).down")
            digital(x < -0.22, key: CGKeyCode(kVK_LeftArrow), owner: "\(owner).left")
            digital(x > 0.22, key: CGKeyCode(kVK_RightArrow), owner: "\(owner).right")
        case .mouse:
            let factor = 22.0
            let dead = 0.05
            let mag = hypot(x, y)
            if mag > dead {
                let normX = x / mag
                let normY = y / mag
                let scaledMag = pow((mag - dead) / (1.0 - dead), 1.25)
                let dx = normX * scaledMag * factor
                let dy = normY * scaledMag * factor
                _ = InputEngine.move(dx: dx, dy: dy)
            }
        case .scroll:
            let dx = x * 12.0
            let dy = -y * 12.0
            if hypot(dx, dy) > 0.2 {
                _ = InputEngine.scroll(dx: dx, dy: dy, phase: .changed)
            }
        case .none:
            break
        }
    }

    private func digital(_ down: Bool, key: CGKeyCode, owner: String) {
        setKeyOwner(owner, key: key, down: down)
    }

    private func setKeyOwner(_ owner: String, key: UInt16, down: Bool) {
        var owners = heldKeyOwners[key] ?? []

        if down {
            let inserted = owners.insert(owner).inserted
            guard inserted else { return }
            heldKeyOwners[key] = owners
            if owners.count == 1 {
                _ = InputEngine.keyDown(code: key, flags: 0)
            }
            return
        }

        guard owners.remove(owner) != nil else { return }
        if owners.isEmpty {
            heldKeyOwners[key] = nil
            _ = InputEngine.keyUp(code: key, flags: 0)
        } else {
            heldKeyOwners[key] = owners
        }
    }
}

enum KeyboardGamepad {
    static let shared = KeyboardGamepadOutput()
}
