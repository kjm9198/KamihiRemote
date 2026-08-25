import CoreGraphics
import Foundation
import Carbon.HIToolbox

protocol GamepadOutput {
    func apply(_ state: ControllerState)
    func reset()
}

final class KeyboardGamepadOutput: GamepadOutput {
    var mapping: GameMapping = .fps
    private var last = ControllerState.neutral
    private var held = Set<UInt16>()

    func apply(_ state: ControllerState) {
        switch mapping {
        case .fps, .custom:
            applyWASD(state)
            applyButton(state, .a, key: CGKeyCode(kVK_Space))
            applyButton(state, .b, key: CGKeyCode(kVK_Shift))
            applyButton(state, .x, key: CGKeyCode(kVK_ANSI_E))
            applyButton(state, .y, key: CGKeyCode(kVK_ANSI_F))
            applyMouseLook(state)
        case .platformer:
            applyWASD(state)
            applyButton(state, .a, key: CGKeyCode(kVK_Space))
            applyButton(state, .b, key: CGKeyCode(kVK_Shift))
        case .racing:
            digital(state.leftY < -0.3, key: CGKeyCode(kVK_UpArrow))
            digital(state.leftY > 0.3, key: CGKeyCode(kVK_DownArrow))
            digital(state.leftX < -0.3, key: CGKeyCode(kVK_LeftArrow))
            digital(state.leftX > 0.3, key: CGKeyCode(kVK_RightArrow))
            applyButton(state, .a, key: CGKeyCode(kVK_Space))
        }
        last = state
    }

    func reset() {
        for key in held {
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
        held.removeAll()
        last = .neutral
    }

    private func applyWASD(_ state: ControllerState) {
        digital(state.leftY < -0.28, key: CGKeyCode(kVK_ANSI_W))
        digital(state.leftY > 0.28, key: CGKeyCode(kVK_ANSI_S))
        digital(state.leftX < -0.28, key: CGKeyCode(kVK_ANSI_A))
        digital(state.leftX > 0.28, key: CGKeyCode(kVK_ANSI_D))
    }

    private func applyMouseLook(_ state: ControllerState) {
        let dx = Double(state.rightX) * 12
        let dy = Double(state.rightY) * 12
        if hypot(dx, dy) > 0.2 {
            _ = InputEngine.move(dx: dx, dy: dy)
        }
    }

    private func applyButton(_ state: ControllerState, _ button: ControllerButton, key: CGKeyCode) {
        digital(state.isDown(button), key: key)
    }

    private func digital(_ down: Bool, key: CGKeyCode) {
        if down {
            if held.contains(key) == false {
                held.insert(key)
                _ = InputEngine.keyDown(code: key, flags: 0)
            }
        } else if held.contains(key) {
            held.remove(key)
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
    }
}

enum KeyboardGamepad {
    static let shared = KeyboardGamepadOutput()
}
