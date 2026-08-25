import AppKit
import Foundation

/// Verifies the public Control+Left/Right Spaces action by observing the workspace's
/// active-space notification. This prevents the Deck from claiming a desktop switch
/// worked when macOS has the corresponding Mission Control shortcut disabled or there
/// is no adjacent Space to move to.
enum SpaceSwitchVerifier {
    static func perform(_ action: SystemAction, completion: @escaping (Bool) -> Void) {
        guard action == .previousDesktop || action == .nextDesktop else {
            completion(InputEngine.perform(action))
            return
        }

        let center = NSWorkspace.shared.notificationCenter
        let lock = NSLock()
        var finished = false
        var token: NSObjectProtocol?

        func finish(_ success: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard finished == false else { return }
            finished = true
            if let token {
                center.removeObserver(token)
            }
            completion(success)
        }

        token = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { _ in
            finish(true)
        }

        guard InputEngine.perform(action) else {
            finish(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            finish(false)
        }
    }
}
