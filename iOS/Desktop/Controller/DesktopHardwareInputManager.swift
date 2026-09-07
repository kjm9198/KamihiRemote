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

    /// Coalesce only active wheel bursts. This is deliberately task-driven rather
    /// than a permanent display link/timer: an MX Master free-spin can otherwise
    /// enqueue many tiny main-actor mutations per frame, while idle desktop energy
    /// remains zero when the wheel is not moving.
    private var pendingScrollDelta: CGSize = .zero
    private var pendingScrollWindowID: UUID?
    private var scrollFlushTask: Task<Void, Never>?

    /// A conservative baseline raw-delta gain tuned for high-DPI productivity
    /// mice such as Logitech MX Master. User sensitivity/acceleration preferences
    /// are applied on top so hardware and the phone trackpad do not feel like two
    /// unrelated pointers.
    private static let hardwarePointerGain: CGFloat = 0.72
    private static let wheelGain: CGFloat = 14.0
    private static let wheelCoalescingMilliseconds = 8

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
            detachConfiguredMouse()
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
        if configuredMouse !== mouse {
            detachConfiguredMouse()
        }
        configuredMouse = mouse
        isMouseConnected = true
        mouseName = mouse.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Hardware Mouse"

        guard let input = mouse.mouseInput else { return }

        input.mouseMovedHandler = { _, deltaX, deltaY in
            Task { @MainActor in
                let desktop = DesktopSession.shared
                let settings = TrackpadSettings.shared
                let delta = Self.hardwarePointerDelta(
                    deltaX: CGFloat(deltaX),
                    deltaY: CGFloat(deltaY),
                    sensitivity: settings.pointerSensitivity,
                    acceleration: settings.pointerAcceleration
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

        input.scroll.valueChangedHandler = { _, xValue, yValue in
            Task { @MainActor in
                let settings = TrackpadSettings.shared
                let delta = Self.hardwareScrollDelta(
                    xValue: CGFloat(xValue),
                    yValue: CGFloat(yValue),
                    speed: settings.scrollSpeed,
                    naturalScrolling: settings.naturalScrolling
                )
                guard hypot(delta.width, delta.height) > 0 else { return }
                self.enqueueHardwareScroll(delta, desktop: DesktopSession.shared)
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

    /// Remove closures from a mouse that is no longer current. iOS can keep more
    /// than one GCMouse object alive while switching Bluetooth/USB devices; leaving
    /// handlers attached risks duplicate pointer/wheel delivery if the old device
    /// emits a late sample. This also drops any wheel burst owned by the old mouse.
    private func detachConfiguredMouse() {
        guard let input = configuredMouse?.mouseInput else {
            configuredMouse = nil
            cancelPendingScroll()
            return
        }

        input.mouseMovedHandler = nil
        input.leftButton.pressedChangedHandler = nil
        input.rightButton?.pressedChangedHandler = nil
        input.scroll.valueChangedHandler = nil
        for button in input.auxiliaryButtons ?? [] {
            button.pressedChangedHandler = nil
        }

        configuredMouse = nil
        cancelPendingScroll()
    }

    /// Batch wheel samples that arrive inside one display-scale slice, then route
    /// one combined delta to the window that owned the burst. If focus changes in
    /// those few milliseconds, discard rather than scrolling a newly-active app.
    private func enqueueHardwareScroll(_ delta: CGSize, desktop: DesktopSession) {
        guard let activeWindowID = desktop.activeWindowID else { return }

        if pendingScrollWindowID != activeWindowID {
            pendingScrollDelta = .zero
            pendingScrollWindowID = activeWindowID
        }
        pendingScrollDelta.width += delta.width
        pendingScrollDelta.height += delta.height

        guard scrollFlushTask == nil else { return }
        scrollFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.wheelCoalescingMilliseconds))
            guard !Task.isCancelled else { return }
            self?.flushPendingScroll(desktop: desktop)
        }
    }

    private func flushPendingScroll(desktop: DesktopSession) {
        scrollFlushTask = nil
        let delta = pendingScrollDelta
        let ownerID = pendingScrollWindowID
        pendingScrollDelta = .zero
        pendingScrollWindowID = nil

        guard hypot(delta.width, delta.height) > 0,
              let ownerID,
              desktop.activeWindowID == ownerID,
              let key = desktop.activeWindow?.title else { return }

        if DesktopNativeScrollRegistry.shared.scroll(key: key, deltaX: delta.width, deltaY: delta.height) {
            return
        }
        desktop.scrollActiveWindow(deltaX: delta.width, deltaY: delta.height)
    }

    private func cancelPendingScroll() {
        scrollFlushTask?.cancel()
        scrollFlushTask = nil
        pendingScrollDelta = .zero
        pendingScrollWindowID = nil
    }

    /// Apply the same user-facing pointer tuning semantics to a physical mouse
    /// without relying on device-specific Logitech APIs. The raw GameController
    /// delta is already high resolution, so this intentionally uses a bounded,
    /// distance-based acceleration gain instead of time-based smoothing. That
    /// keeps low-speed MX Master motion precise while still honoring the Fast /
    /// Precision profiles and avoiding an idle timer or extra frame loop.
    static func hardwarePointerDelta(
        deltaX: CGFloat,
        deltaY: CGFloat,
        sensitivity: Double,
        acceleration: Double
    ) -> CGSize {
        let normalizedSensitivity = CGFloat(TrackpadSettings.normalizedPointerSensitivity(sensitivity))
        let normalizedAcceleration = CGFloat(TrackpadSettings.normalizedPointerAcceleration(acceleration))
        let rawDistance = hypot(deltaX, deltaY)
        let accelerationProgress = min(max((rawDistance - 1.0) / 18.0, 0), 1)
        let accelerationGain = 1.0 + normalizedAcceleration * accelerationProgress * 0.22
        let gain = min(Self.hardwarePointerGain * normalizedSensitivity * accelerationGain, 2.2)

        return CGSize(
            width: deltaX * gain,
            // GameController reports positive Y upward; Kamihi's normalized
            // desktop coordinate grows downward.
            height: -deltaY * gain
        )
    }

    /// Converts high-resolution mouse-wheel samples into Kamihi's two-axis scroll
    /// coordinates while suppressing tiny cross-axis sensor noise. This is
    /// especially important for MX Master-class wheels: a vertical free-spin
    /// should not slowly drift a spreadsheet/browser sideways, and the horizontal
    /// thumb wheel should not make content bob vertically. Genuine diagonal input
    /// is preserved whenever both axes are substantial.
    static func hardwareScrollDelta(
        xValue: CGFloat,
        yValue: CGFloat,
        speed: Double,
        naturalScrolling: Bool
    ) -> CGSize {
        var x = abs(xValue) < 0.025 ? 0 : xValue
        var y = abs(yValue) < 0.025 ? 0 : yValue

        let absX = abs(x)
        let absY = abs(y)
        if absX > 0, absY > 0 {
            if absX < absY * 0.24 {
                x = 0
            } else if absY < absX * 0.24 {
                y = 0
            }
        }

        let direction: CGFloat = naturalScrolling ? -1 : 1
        let boundedSpeed = CGFloat(min(max(speed, 0.35), 2.5))
        let gain = Self.wheelGain * boundedSpeed * direction
        return CGSize(
            width: x * gain,
            // GameController wheel Y is positive upward while content-space Y
            // grows downward, matching the existing trackpad scroll convention.
            height: -y * gain
        )
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
