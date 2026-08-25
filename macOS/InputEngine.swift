import AppKit
import ApplicationServices
import CoreGraphics
import Carbon.HIToolbox

enum InputEngine {
    private static var mouseIsDown = false
    private static var rightMouseIsDown = false
    private static var heldKeys = Set<UInt16>()
    private static let source = CGEventSource(stateID: .hidSystemState)
    private static var remainderX = 0.0
    private static var remainderY = 0.0

    static var canInjectEvents: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func move(dx: Double, dy: Double) -> Bool {
        guard canInjectEvents else { return false }
        remainderX += dx
        remainderY += dy
        let stepX = remainderX
        let stepY = remainderY
        remainderX = 0
        remainderY = 0
        let current = CGEvent(source: nil)?.location ?? .zero
        let next = clamp(CGPoint(x: current.x + stepX, y: current.y + stepY))
        let type: CGEventType = mouseIsDown ? .leftMouseDragged : .mouseMoved
        return postMouse(type: type, at: next, button: .left)
    }

    @discardableResult
    static func click() -> Bool {
        return click(count: 1)
    }

    @discardableResult
    static func doubleClick() -> Bool {
        return click(count: 1) && click(count: 2)
    }

    private static func click(count: Int64) -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        let down = postMouse(type: .leftMouseDown, at: point, button: .left, clickCount: count)
        let up = postMouse(type: .leftMouseUp, at: point, button: .left, clickCount: count)
        mouseIsDown = false
        return down && up
    }

    @discardableResult
    static func rightClick() -> Bool {
        guard canInjectEvents else { return false }
        let point = CGEvent(source: nil)?.location ?? .zero
        let down = postMouse(type: .rightMouseDown, at: point, button: .right)
        let up = postMouse(type: .rightMouseUp, at: point, button: .right)
        rightMouseIsDown = false
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
    static func scroll(dx: Double, dy: Double, phase: ScrollPhase = .changed) -> Bool {
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
        switch phase {
        case .began:
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.began.rawValue))
        case .changed:
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.changed.rawValue))
        case .ended:
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.ended.rawValue))
        case .momentumBegan:
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(CGMomentumScrollPhase.begin.rawValue))
        case .momentumChanged:
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
        case .momentumEnded:
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(CGMomentumScrollPhase.end.rawValue))
        }
        event.post(tap: .cghidEventTap)
        return true
    }

    @discardableResult
    static func pinch(_ delta: Double) -> Bool {
        zoom(delta >= 0 ? .in : .out)
    }

    @discardableResult
    static func zoom(_ action: ZoomAction) -> Bool {
        switch action {
        case .in:
            return shortcut("cmd+=")
        case .out:
            return shortcut("cmd+-")
        }
    }

    @discardableResult
    static func keyDown(code: UInt16, flags: UInt64) -> Bool {
        heldKeys.insert(code)
        return postKey(code: code, flags: CGEventFlags(rawValue: flags), down: true)
    }

    @discardableResult
    static func keyUp(code: UInt16, flags: UInt64) -> Bool {
        heldKeys.remove(code)
        return postKey(code: code, flags: CGEventFlags(rawValue: flags), down: false)
    }

    @discardableResult
    static func typeText(_ text: String) -> Bool {
        guard canInjectEvents else { return false }
        var ok = true
        for scalar in text.unicodeScalars {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { continue }
            var chars = Array(String(scalar).utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event.post(tap: .cghidEventTap)
            event.type = .keyUp
            event.post(tap: .cghidEventTap)
            ok = true
        }
        return ok
    }

    @discardableResult
    static func perform(_ action: SystemAction) -> Bool {
        switch action {
        case .none:
            return true
        case .missionControl:
            // Prefer opening Mission Control.app — more reliable than Control+Up when
            // the user remapped Mission Control shortcuts.
            if openMissionControlApp() { return true }
            return hotkey(key: CGKeyCode(kVK_UpArrow), flags: .maskControl)
        case .appExpose:
            if hotkey(key: CGKeyCode(kVK_DownArrow), flags: .maskControl) { return true }
            if hotkey(key: CGKeyCode(kVK_F10), flags: []) { return true }
            return hotkey(key: CGKeyCode(kVK_F3), flags: [])
        case .previousDesktop:
            if hotkey(key: CGKeyCode(kVK_LeftArrow), flags: .maskControl) { return true }
            return hotkey(key: CGKeyCode(kVK_LeftArrow), flags: [.maskControl, .maskShift])
        case .nextDesktop:
            if hotkey(key: CGKeyCode(kVK_RightArrow), flags: .maskControl) { return true }
            return hotkey(key: CGKeyCode(kVK_RightArrow), flags: [.maskControl, .maskShift])
        case .showDesktop:
            if hotkey(key: CGKeyCode(kVK_F11), flags: []) { return true }
            return hotkey(key: CGKeyCode(kVK_ANSI_D), flags: [.maskCommand, .maskControl])
        case .launchpad:
            return hotkey(key: CGKeyCode(kVK_F4), flags: [])
        case .playPause:
            return media(.playPause)
        case .customShortcut:
            return true
        }
    }

    @discardableResult
    private static func openMissionControlApp() -> Bool {
        let path = "/System/Applications/Mission Control.app"
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return true
    }

    @discardableResult
    static func media(_ action: MediaAction) -> Bool {
        let key: Int32
        switch action {
        case .playPause: key = NX_KEYTYPE_PLAY
        case .next: key = NX_KEYTYPE_NEXT
        case .previous: key = NX_KEYTYPE_PREVIOUS
        case .volumeUp: key = NX_KEYTYPE_SOUND_UP
        case .volumeDown: key = NX_KEYTYPE_SOUND_DOWN
        case .mute: key = NX_KEYTYPE_MUTE
        }
        return postMedia(key)
    }

    @discardableResult
    static func presentation(_ action: PresentationAction, profile: PresentationProfile = .keynote) -> Bool {
        switch action {
        case .next:
            return hotkey(key: CGKeyCode(kVK_RightArrow), flags: [])
        case .previous:
            return hotkey(key: CGKeyCode(kVK_LeftArrow), flags: [])
        case .start:
            switch profile {
            case .powerpoint:
                return hotkey(key: CGKeyCode(kVK_F5), flags: [])
            case .generic:
                return hotkey(key: CGKeyCode(kVK_Return), flags: .maskCommand)
            case .keynote:
                return hotkey(key: CGKeyCode(kVK_ANSI_P), flags: [.maskCommand, .maskShift])
            }
        case .end:
            return hotkey(key: CGKeyCode(kVK_Escape), flags: [])
        case .black:
            switch profile {
            case .powerpoint:
                return hotkey(key: CGKeyCode(kVK_ANSI_B), flags: [])
            case .generic:
                return hotkey(key: CGKeyCode(kVK_ANSI_B), flags: [])
            case .keynote:
                return hotkey(key: CGKeyCode(kVK_ANSI_B), flags: [])
            }
        case .pointer:
            LaserOverlay.setVisible(true)
            return true
        }
    }

    @discardableResult
    static func shortcut(_ spec: String) -> Bool {
        let parts = spec.lowercased().split(separator: "+").map(String.init)
        var flags: CGEventFlags = []
        var key: CGKeyCode?
        for part in parts {
            switch part {
            case "cmd", "command": flags.insert(.maskCommand)
            case "alt", "option": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            default:
                key = keyCode(for: part)
            }
        }
        guard let key else { return false }
        return hotkey(key: key, flags: flags)
    }

    @discardableResult
    static func openApplication(_ name: String) -> Bool {
        if name.contains(".") {
            return AppCatalog.open(bundleIdentifier: name)
        }
        return AppCatalog.open(bundleIdentifier: name) || NSWorkspace.shared.launchApplication(name)
    }

    static func releaseAll() {
        if mouseIsDown { _ = mouseUp() }
        if rightMouseIsDown {
            let point = CGEvent(source: nil)?.location ?? .zero
            _ = postMouse(type: .rightMouseUp, at: point, button: .right)
            rightMouseIsDown = false
        }
        for key in heldKeys {
            _ = postKey(code: key, flags: [], down: false)
        }
        heldKeys.removeAll()
        KeyboardGamepad.shared.reset()
        LaserOverlay.setVisible(false)
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

    @discardableResult
    static func openURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: value) else { return false }
        return NSWorkspace.shared.open(url)
    }

    static func apply(_ command: RemoteCommand) -> Bool {
        switch command {
        case .move(let dx, let dy):
            return move(dx: dx, dy: dy)
        case .click:
            return click()
        case .doubleClick:
            return doubleClick()
        case .rightClick:
            return rightClick()
        case .scroll(let dx, let dy, let phase):
            return scroll(dx: dx, dy: dy, phase: phase)
        case .mouseDown:
            return mouseDown()
        case .mouseUp:
            return mouseUp()
        case .releaseAll:
            releaseAll()
            return true
        case .keyDown(let code, let flags):
            return keyDown(code: code, flags: flags)
        case .keyUp(let code, let flags):
            return keyUp(code: code, flags: flags)
        case .typeText(let text):
            return typeText(text)
        case .system(let action):
            return perform(action)
        case .media(let action):
            return media(action)
        case .presentation(let action, let profile):
            return presentation(action, profile: profile)
        case .pinch(let delta):
            return pinch(delta)
        case .zoom(let action):
            return zoom(action)
        case .openApp(let bundleID):
            return openApplication(bundleID)
        case .openURL(let url):
            return openURL(url)
        case .shortcut(let spec):
            return shortcut(spec)
        case .laser(let x, let y):
            LaserOverlay.move(normalizedX: x, normalizedY: y)
            return true
        case .laserVisible(let visible):
            LaserOverlay.setVisible(visible)
            return true
        case .controller(let state):
            KeyboardGamepad.shared.apply(state)
            return true
        default:
            return false
        }
    }

    private static func hotkey(key: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard canInjectEvents else { return false }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func postKey(code: UInt16, flags: CGEventFlags, down: Bool) -> Bool {
        guard canInjectEvents else { return false }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return false }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func postMedia(_ key: Int32) -> Bool {
        func post(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((key << 16) | (down ? 0xA00 : 0xB00))
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        post(down: true)
        post(down: false)
        return true
    }

    private static func keyChord(command: Bool, key: CGKeyCode?, downUp: Bool) -> Bool {
        true
    }

    private static func keyCode(for name: String) -> CGKeyCode? {
        switch name {
        case "a": return CGKeyCode(kVK_ANSI_A)
        case "b": return CGKeyCode(kVK_ANSI_B)
        case "c": return CGKeyCode(kVK_ANSI_C)
        case "d": return CGKeyCode(kVK_ANSI_D)
        case "e": return CGKeyCode(kVK_ANSI_E)
        case "f": return CGKeyCode(kVK_ANSI_F)
        case "s": return CGKeyCode(kVK_ANSI_S)
        case "v": return CGKeyCode(kVK_ANSI_V)
        case "w": return CGKeyCode(kVK_ANSI_W)
        case "z": return CGKeyCode(kVK_ANSI_Z)
        case "=", "plus", "equal": return CGKeyCode(kVK_ANSI_Equal)
        case "-", "minus": return CGKeyCode(kVK_ANSI_Minus)
        case "4": return CGKeyCode(kVK_ANSI_4)
        case "space": return CGKeyCode(kVK_Space)
        case "tab": return CGKeyCode(kVK_Tab)
        case "esc", "escape": return CGKeyCode(kVK_Escape)
        case "return", "enter": return CGKeyCode(kVK_Return)
        case "left": return CGKeyCode(kVK_LeftArrow)
        case "right": return CGKeyCode(kVK_RightArrow)
        case "up": return CGKeyCode(kVK_UpArrow)
        case "down": return CGKeyCode(kVK_DownArrow)
        default:
            return nil
        }
    }

    private static func postMouse(type: CGEventType, at point: CGPoint, button: CGMouseButton, clickCount: Int64 = 1) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return false }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
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
