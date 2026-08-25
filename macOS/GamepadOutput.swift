import CoreGraphics
import Foundation
import Carbon.HIToolbox

protocol GamepadOutput {
    func apply(_ state: ControllerState)
    func reset()
}

/// Keyboard/mouse fallback gamepad output for games that do not consume a native virtual controller.
///
/// Controller packets are event-driven, but mouse-look and scrolling are continuous actions. We retain
/// the latest analog state and render those actions at a stable 90 Hz on a dedicated serial queue. This
/// means holding a stick still continues to turn/scroll without requiring the phone to waste bandwidth
/// retransmitting an identical state every frame.
final class KeyboardGamepadOutput: GamepadOutput {
    private let queue = DispatchQueue(label: "kamihi.gamepad.output", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    private var activeMapping: ControllerMapping = .gaming
    var mapping: ControllerMapping {
        get { queue.sync { activeMapping } }
        set {
            queue.async { [weak self] in
                guard let self else { return }
                self.resetLocked()
                self.activeMapping = newValue
            }
        }
    }

    private var last = ControllerState.neutral
    private var current = ControllerState.neutral

    /// A key can be owned by more than one controller source (for example A and R2 both mapped to Space).
    /// The physical key is released only after the final owner lets go.
    private var keyOwners: [UInt16: Set<String>] = [:]
    private var leftMouseOwners = Set<String>()
    private var rightMouseOwners = Set<String>()

    private var leftTriggerDown = false
    private var rightTriggerDown = false
    private var scrollActive = false

    init() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + .milliseconds(10),
            repeating: 1.0 / RemoteConstants.controllerHz,
            leeway: .milliseconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.renderContinuousOutput()
        }
        self.timer = timer
        timer.resume()
    }

    deinit {
        timer?.cancel()
    }

    func apply(_ state: ControllerState) {
        queue.async { [weak self] in
            self?.applyLocked(state)
        }
    }

    func reset() {
        queue.sync {
            resetLocked()
        }
    }

    private func applyLocked(_ state: ControllerState) {
        let mapping = activeMapping

        // Face / shoulder / navigation buttons.
        applyAction(mapping.a, down: state.isDown(.a), wasDown: last.isDown(.a), owner: "button.a")
        applyAction(mapping.b, down: state.isDown(.b), wasDown: last.isDown(.b), owner: "button.b")
        applyAction(mapping.x, down: state.isDown(.x), wasDown: last.isDown(.x), owner: "button.x")
        applyAction(mapping.y, down: state.isDown(.y), wasDown: last.isDown(.y), owner: "button.y")
        applyAction(mapping.l1, down: state.isDown(.l1), wasDown: last.isDown(.l1), owner: "button.l1")
        applyAction(mapping.r1, down: state.isDown(.r1), wasDown: last.isDown(.r1), owner: "button.r1")
        applyAction(mapping.start, down: state.isDown(.start), wasDown: last.isDown(.start), owner: "button.start")
        applyAction(mapping.menu, down: state.isDown(.menu), wasDown: last.isDown(.menu), owner: "button.menu")
        applyAction(mapping.view, down: state.isDown(.view), wasDown: last.isDown(.view), owner: "button.view")
        applyAction(mapping.l3, down: state.isDown(.l3), wasDown: last.isDown(.l3), owner: "button.l3")
        applyAction(mapping.r3, down: state.isDown(.r3), wasDown: last.isDown(.r3), owner: "button.r3")

        // Analog triggers use hysteresis so values hovering around the threshold do not chatter.
        let previousLeftTrigger = leftTriggerDown
        let previousRightTrigger = rightTriggerDown
        leftTriggerDown = triggerState(value: state.leftTrigger, currentlyDown: leftTriggerDown)
        rightTriggerDown = triggerState(value: state.rightTrigger, currentlyDown: rightTriggerDown)
        applyAction(mapping.l2, down: leftTriggerDown, wasDown: previousLeftTrigger, owner: "trigger.l2")
        applyAction(mapping.r2, down: rightTriggerDown, wasDown: previousRightTrigger, owner: "trigger.r2")

        // D-Pad supports diagonals without prematurely releasing either axis.
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

        applyAction(mapping.dpadUp, down: up, wasDown: lastUp, owner: "dpad.up")
        applyAction(mapping.dpadDown, down: down, wasDown: lastDown, owner: "dpad.down")
        applyAction(mapping.dpadLeft, down: left, wasDown: lastLeft, owner: "dpad.left")
        applyAction(mapping.dpadRight, down: right, wasDown: lastRight, owner: "dpad.right")

        // WASD/arrow sticks are stateful key holds and only need transitions. Mouse/scroll are rendered
        // continuously by renderContinuousOutput().
        applyDigitalStick(mapping.leftStick, x: Double(state.leftX), y: Double(state.leftY), owner: "stick.left")
        applyDigitalStick(mapping.rightStick, x: Double(state.rightX), y: Double(state.rightY), owner: "stick.right")

        current = state
        last = state
    }

    private func resetLocked() {
        if scrollActive {
            _ = InputEngine.scroll(dx: 0, dy: 0, phase: .ended)
            scrollActive = false
        }

        if leftMouseOwners.isEmpty == false {
            _ = InputEngine.mouseUp()
            leftMouseOwners.removeAll()
        }

        if rightMouseOwners.isEmpty == false {
            postRightMouse(down: false)
            rightMouseOwners.removeAll()
        }

        for key in keyOwners.keys {
            _ = InputEngine.keyUp(code: key, flags: 0)
        }
        keyOwners.removeAll()

        leftTriggerDown = false
        rightTriggerDown = false
        current = .neutral
        last = .neutral
    }

    private func applyAction(_ action: ControllerAction, down: Bool, wasDown: Bool, owner: String) {
        guard down != wasDown else { return }

        switch action {
        case .none:
            break
        case .key(let code, _):
            setKey(code, down: down, owner: owner)
        case .shortcut(let spec, _):
            if down {
                _ = InputEngine.shortcut(spec)
            }
        case .click:
            setLeftMouse(down: down, owner: owner)
        case .rightClick:
            // Right mouse is a held gaming control (default L2 / aim), not a one-shot context click.
            setRightMouse(down: down, owner: owner)
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

    private func triggerState(value: Float, currentlyDown: Bool) -> Bool {
        if currentlyDown {
            return value > 0.30
        }
        return value >= 0.45
    }

    private func applyDigitalStick(_ action: StickAction, x: Double, y: Double, owner: String) {
        switch action {
        case .wasd:
            digital(y < -0.22, key: CGKeyCode(kVK_ANSI_W), owner: owner + ".up")
            digital(y > 0.22, key: CGKeyCode(kVK_ANSI_S), owner: owner + ".down")
            digital(x < -0.22, key: CGKeyCode(kVK_ANSI_A), owner: owner + ".left")
            digital(x > 0.22, key: CGKeyCode(kVK_ANSI_D), owner: owner + ".right")
        case .arrows:
            digital(y < -0.22, key: CGKeyCode(kVK_UpArrow), owner: owner + ".up")
            digital(y > 0.22, key: CGKeyCode(kVK_DownArrow), owner: owner + ".down")
            digital(x < -0.22, key: CGKeyCode(kVK_LeftArrow), owner: owner + ".left")
            digital(x > 0.22, key: CGKeyCode(kVK_RightArrow), owner: owner + ".right")
        case .mouse, .scroll, .none:
            break
        }
    }

    private func renderContinuousOutput() {
        let mapping = activeMapping
        let state = current

        var mouseDX = 0.0
        var mouseDY = 0.0
        var scrollDX = 0.0
        var scrollDY = 0.0

        accumulateContinuous(
            mapping.leftStick,
            x: Double(state.leftX),
            y: Double(state.leftY),
            mouseDX: &mouseDX,
            mouseDY: &mouseDY,
            scrollDX: &scrollDX,
            scrollDY: &scrollDY
        )
        accumulateContinuous(
            mapping.rightStick,
            x: Double(state.rightX),
            y: Double(state.rightY),
            mouseDX: &mouseDX,
            mouseDY: &mouseDY,
            scrollDX: &scrollDX,
            scrollDY: &scrollDY
        )

        if hypot(mouseDX, mouseDY) > 0.001 {
            _ = InputEngine.move(dx: mouseDX, dy: mouseDY)
        }

        let hasScroll = hypot(scrollDX, scrollDY) > 0.2
        if hasScroll {
            _ = InputEngine.scroll(
                dx: scrollDX,
                dy: scrollDY,
                phase: scrollActive ? .changed : .began
            )
            scrollActive = true
        } else if scrollActive {
            _ = InputEngine.scroll(dx: 0, dy: 0, phase: .ended)
            scrollActive = false
        }
    }

    private func accumulateContinuous(
        _ action: StickAction,
        x: Double,
        y: Double,
        mouseDX: inout Double,
        mouseDY: inout Double,
        scrollDX: inout Double,
        scrollDY: inout Double
    ) {
        switch action {
        case .mouse:
            let dead = 0.045
            let mag = min(hypot(x, y), 1.0)
            guard mag > dead else { return }
            let normX = x / max(mag, 0.0001)
            let normY = y / max(mag, 0.0001)
            let normalized = (mag - dead) / (1.0 - dead)
            let curve = pow(normalized, 1.35)
            let pixelsPerTick = 10.0
            mouseDX += normX * curve * pixelsPerTick
            mouseDY += normY * curve * pixelsPerTick
        case .scroll:
            let gain = 3.2
            scrollDX += x * gain
            scrollDY += -y * gain
        case .wasd, .arrows, .none:
            break
        }
    }

    private func digital(_ down: Bool, key: CGKeyCode, owner: String) {
        setKey(key, down: down, owner: owner)
    }

    private func setKey(_ key: UInt16, down: Bool, owner: String) {
        var owners = keyOwners[key] ?? []

        if down {
            guard owners.contains(owner) == false else { return }
            let wasEmpty = owners.isEmpty
            owners.insert(owner)
            keyOwners[key] = owners
            if wasEmpty {
                _ = InputEngine.keyDown(code: key, flags: 0)
            }
            return
        }

        guard owners.remove(owner) != nil else { return }
        if owners.isEmpty {
            keyOwners.removeValue(forKey: key)
            _ = InputEngine.keyUp(code: key, flags: 0)
        } else {
            keyOwners[key] = owners
        }
    }

    private func setLeftMouse(down: Bool, owner: String) {
        if down {
            guard leftMouseOwners.contains(owner) == false else { return }
            let wasEmpty = leftMouseOwners.isEmpty
            leftMouseOwners.insert(owner)
            if wasEmpty {
                _ = InputEngine.mouseDown()
            }
            return
        }

        guard leftMouseOwners.remove(owner) != nil else { return }
        if leftMouseOwners.isEmpty {
            _ = InputEngine.mouseUp()
        }
    }

    private func setRightMouse(down: Bool, owner: String) {
        if down {
            guard rightMouseOwners.contains(owner) == false else { return }
            let wasEmpty = rightMouseOwners.isEmpty
            rightMouseOwners.insert(owner)
            if wasEmpty {
                postRightMouse(down: true)
            }
            return
        }

        guard rightMouseOwners.remove(owner) != nil else { return }
        if rightMouseOwners.isEmpty {
            postRightMouse(down: false)
        }
    }

    private func postRightMouse(down: Bool) {
        guard InputEngine.canInjectEvents else { return }
        let point = CGEvent(source: nil)?.location ?? .zero
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: down ? .rightMouseDown : .rightMouseUp,
            mouseCursorPosition: point,
            mouseButton: .right
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}

enum KeyboardGamepad {
    static let shared = KeyboardGamepadOutput()
}
