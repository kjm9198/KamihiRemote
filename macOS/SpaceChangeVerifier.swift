import AppKit
import Foundation

enum SpaceChangeVerifier {
    /// Wait for a Space change without using private Mission Control APIs.
    static func wait(timeout: TimeInterval = RemoteConstants.spaceChangeTimeout) async -> Bool {
        await withCheckedContinuation { continuation in
            var finished = false
            let center = NSWorkspace.shared.notificationCenter
            var observer: NSObjectProtocol?
            observer = center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
                guard finished == false else { return }
                finished = true
                if let observer { center.removeObserver(observer) }
                continuation.resume(returning: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                guard finished == false else { return }
                finished = true
                if let observer { center.removeObserver(observer) }
                continuation.resume(returning: false)
            }
        }
    }
}
