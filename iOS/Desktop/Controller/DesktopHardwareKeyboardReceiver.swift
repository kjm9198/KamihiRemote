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

        func setCaptureEnabled(_ enabled: Bool) {
            guard captureEnabled != enabled else {
                if enabled, !isFirstResponder {
                    becomeFirstResponderOnNextRunLoop()
                }
                return
            }

            captureEnabled = enabled
            if enabled {
                becomeFirstResponderOnNextRunLoop()
            } else if isFirstResponder {
                resignFirstResponder()
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

        private func becomeFirstResponderOnNextRunLoop() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.captureEnabled, self.window != nil else { return }
                _ = self.becomeFirstResponder()
            }
        }
    }
}
