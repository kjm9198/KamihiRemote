import Foundation
import GameController
import UIKit

/// Bridges physical HID devices into Kamihi's virtual desktop pointer while
/// preserving UIKit's native hardware-keyboard text input path.
///
/// iOS abstracts transport, so the same code works for Bluetooth and USB-C/wired
/// keyboards and mice that the system recognizes. Mouse movement/buttons/wheels
/// are read through GameController and routed into the same DesktopSession used
/// by the iPhone trackpad. Keyboard text remains owned by UIKit/SwiftUI so we do
/// not double-type or intercept secure fields; DesktopHardwareShortcutLayer adds
/// desktop shortcuts on top of that native text path.
@MainActor
final class DesktopHardwareInputManager: ObservableObject {
    static let shared = DesktopHardwareInputManager()

    @Published private(set) var isMouseConnected = false
    @Published private(set) var isKeyboardConnected = false
    @Published private(set) var mouseName = "Mouse"
    @Published private(set) var keyboardName = "Keyboard"

    private var observers: [NSObjectProtocol] = []
    private var configuredMouse: GCMouse?
    private var started = false

    /// A conservative raw-delta gain tuned for high-DPI productivity mice such
    /// as Logitech MX Master. DesktopSession still applies its bounded pointer
    /// acceleration curve, so slow movement remains precise and fast movement
    /// can cross a 1080p desktop without feeling twitchy.
    private let hardwarePointerGain: CGFloat = 0.72
    private let wheelGain: CGFloat = 14.0

    private init() {}

    func start() {
        guard !started else {
            refreshConnectedDevices()
            return
        }
        started = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .GCMouseDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let mouse = notification.object as? GCMouse else { return }
            Task { @MainActor in self?.configure(mouse: mouse) }
        })
        observers.append(center.addObserver(
            forName: .GCMouseDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshConnectedDevices() }
        })
        observers.append(center.addObserver(
            forName: .GCMouseDidBecomeCurrent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let mouse = notification.object as? GCMouse else { return }
            Task { @MainActor in self?.configure(mouse: mouse) }
        })
        observers.append(center.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshKeyboard() }
        })
        observers.append(center.addObserver(
            forName: .GCKeyboardDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshKeyboard() }
        })

        refreshConnectedDevices()
    }

    private func refreshConnectedDevices() {
        if let mouse = GCMouse.current ?? GCMouse.mice().last {
            configure(mouse: mouse)
        } else {
            configuredMouse = nil
            isMouseConnected = false
            mouseName = "Mouse"
        }
        refreshKeyboard()
    }

    private func refreshKeyboard() {
        if let keyboard = GCKeyboard.coalesced {
            isKeyboardConnected = true
            keyboardName = keyboard.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Hardware Keyboard"
        } else {
            isKeyboardConnected = false
            keyboardName = "Keyboard"
        }
    }

    private func configure(mouse: GCMouse) {
        configuredMouse = mouse
        isMouseConnected = true
        mouseName = mouse.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Hardware Mouse"

        guard let input = mouse.mouseInput else { return }

        input.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
            Task { @MainActor in
                guard let self else { return }
                let desktop = DesktopSession.shared
                let delta = CGSize(
                    width: CGFloat(deltaX) * self.hardwarePointerGain,
                    // GameController reports positive Y upward; Kamihi's
                    // normalized desktop coordinate grows downward.
                    height: -CGFloat(deltaY) * self.hardwarePointerGain
                )

                // Window drag/resize owns pointer advancement internally. Routing
                // the same physical delta through movePointer first would apply it
                // twice and make MX Master drags feel unnaturally fast.
                if desktop.isDraggingWindow || desktop.isResizingWindow {
                    desktop.updateWindowDrag(delta: delta)
                } else {
                    desktop.movePointer(delta: delta, sensitivity: 1.0, immediateDockReveal: true)
                }
            }
        }

        input.leftButton.pressedChangedHandler = { _, _, pressed in
            Task { @MainActor in
                let desktop = DesktopSession.shared
                if pressed {
                    self.handlePrimaryMouseDown(desktop: desktop)
                } else if desktop.isDraggingWindow || desktop.isResizingWindow {
                    desktop.endWindowDrag()
                }
            }
        }

        input.rightButton?.pressedChangedHandler = { _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                DesktopSession.shared.contextClickAtCursorUsingRegistry()
            }
        }

        input.scroll.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                guard let self else { return }
                let desktop = DesktopSession.shared
                let settings = TrackpadSettings.shared
                let direction: CGFloat = settings.naturalScrolling ? -1 : 1
                let deltaX = CGFloat(xValue) * self.wheelGain * CGFloat(settings.scrollSpeed) * direction
                let deltaY = -CGFloat(yValue) * self.wheelGain * CGFloat(settings.scrollSpeed) * direction

                guard let key = desktop.activeWindow?.title else { return }
                if DesktopNativeScrollRegistry.shared.scroll(key: key, deltaX: deltaX, deltaY: deltaY) {
                    return
                }
                desktop.scrollActiveWindow(deltaX: deltaX, deltaY: deltaY)
            }
        }

        // MX Master-style side buttons are exposed as auxiliary mouse buttons.
        // The first pair follows the conventional browser Back/Forward mapping.
        for (index, button) in (input.auxiliaryButtons ?? []).enumerated() {
            button.pressedChangedHandler = { _, _, pressed in
                guard pressed else { return }
                Task { @MainActor in
                    let desktop = DesktopSession.shared
                    guard desktop.activeWindow?.title == "Browser" else { return }
                    if index == 0 {
                        desktop.goBackInActiveBrowser()
                    } else if index == 1 {
                        desktop.goForwardInActiveBrowser()
                    }
                }
            }
        }
    }

    /// Physical mice should behave differently from the phone's gesture surface:
    /// pressing on a window edge/title bar can begin direct manipulation
    /// immediately, but clicking a traffic-light control must remain only a click.
    /// Resolving intent before dispatch prevents Close/Minimize/Maximize from
    /// changing focus and then accidentally arming a drag on the window underneath.
    private func handlePrimaryMouseDown(desktop: DesktopSession) {
        if DesktopDockHitRegistry.shared.hitTest(at: desktop.cursor) != nil {
            desktop.clickAtCursor()
            return
        }

        guard let targetID = desktop.topWindow(at: desktop.cursor),
              let target = desktop.windows.first(where: { $0.id == targetID }) else {
            desktop.clickAtCursor()
            return
        }

        let frame = desktop.effectiveFrame(for: target)
        if DesktopWindowChrome.action(at: desktop.cursor, in: frame) != nil {
            desktop.clickAtCursor()
            return
        }

        if desktop.resizeEdgeAtCursor() != nil {
            _ = desktop.beginPointerResize()
            return
        }

        if desktop.isCursorOverTitleBar() {
            _ = desktop.beginWindowDrag()
            return
        }

        desktop.clickAtCursor()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
