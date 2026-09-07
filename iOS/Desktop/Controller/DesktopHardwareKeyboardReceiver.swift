import SwiftUI
import UIKit

/// Invisible first-responder bridge for a physical keyboard attached to the iPhone.
///
/// The external display is intentionally non-interactive, so hardware keyboard text
/// arrives on the iPhone scene. This receiver forwards only ordinary text editing
/// into the currently focused Kamihi field through DesktopSession's existing app/
/// WebView input routes. Command shortcuts continue to bubble to SwiftUI's
/// DesktopHardwareShortcutLayer and passwords/passkeys remain owned by WebKit/iOS.
struct DesktopHardwareKeyboardReceiver: UIViewRepresentable {
    let isEnabled: Bool
    let desktop: DesktopSession

    func makeUIView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.desktop = desktop
        return view
    }

    func updateUIView(_ uiView: KeyboardCaptureView, context: Context) {
        uiView.desktop = desktop
        uiView.setCaptureEnabled(isEnabled)
    }

    static func dismantleUIView(_ uiView: KeyboardCaptureView, coordinator: ()) {
        uiView.setCaptureEnabled(false)
    }

    @MainActor
    final class KeyboardCaptureView: UIView, UIKeyInput {
        weak var desktop: DesktopSession?
        private let suppressedSoftwareKeyboard = UIView(frame: .zero)
        private var captureEnabled = false
        private var editingObserver: NSObjectProtocol?

        override var canBecomeFirstResponder: Bool { captureEnabled }
        override var inputView: UIView? { suppressedSoftwareKeyboard }
        var hasText: Bool { false }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            accessibilityElementsHidden = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            if let editingObserver {
                NotificationCenter.default.removeObserver(editingObserver)
            }
        }

        func setCaptureEnabled(_ enabled: Bool) {
            guard captureEnabled != enabled else {
                if enabled, !isFirstResponder {
                    becomeFirstResponderOnNextRunLoop()
                }
                return
            }

            captureEnabled = enabled
            if enabled {
                installEditingObserverIfNeeded()
                becomeFirstResponderOnNextRunLoop()
            } else {
                removeEditingObserver()
                if isFirstResponder { resignFirstResponder() }
            }
        }

        func insertText(_ text: String) {
            guard captureEnabled, let desktop else { return }
            if text == "\n" || text == "\r" || text == "\r\n" {
                desktop.pressEnterInActiveDesktopField()
            } else if !text.isEmpty {
                desktop.typeIntoActiveDesktopField(text)
            }
        }

        func deleteBackward() {
            guard captureEnabled else { return }
            desktop?.deleteBackwardInActiveDesktopField()
        }

        private func installEditingObserverIfNeeded() {
            guard editingObserver == nil else { return }
            editingObserver = NotificationCenter.default.addObserver(
                forName: UITextField.textDidBeginEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // The phone controller may present its software-keyboard proxy
                // immediately after a desktop field click. When a physical keyboard
                // is connected, reclaim first responder on the next run loop so the
                // proxy cannot steal hardware keystrokes or summon an unnecessary
                // software keyboard. Manually opening the phone keyboard still works
                // when no desktop field currently requests hardware focus.
                Task { @MainActor in self?.becomeFirstResponderOnNextRunLoop() }
            }
        }

        private func removeEditingObserver() {
            if let editingObserver {
                NotificationCenter.default.removeObserver(editingObserver)
                self.editingObserver = nil
            }
        }

        private func becomeFirstResponderOnNextRunLoop() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.captureEnabled, self.window != nil else { return }
                _ = self.becomeFirstResponder()
            }
        }
    }
}
