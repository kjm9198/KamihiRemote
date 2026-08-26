import AppKit
import Foundation

/// Waits for macOS Space changes without relying on private Mission Control APIs.
/// Notification delivery and timeout resolution can race, so state is protected by a lock.
final class SpaceChangeObserver: @unchecked Sendable {
    private let lock = NSLock()
    private let center = NSWorkspace.shared.notificationCenter
    private var finished = false
    private var result = false
    private var observer: NSObjectProtocol?
    private var continuation: CheckedContinuation<Bool, Never>?

    init() {
        observer = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resolve(true)
        }
    }

    deinit {
        let observerToRemove = lock.withLock { () -> NSObjectProtocol? in
            let current = observer
            observer = nil
            return current
        }
        if let observerToRemove {
            center.removeObserver(observerToRemove)
        }
    }

    func wait(timeout: TimeInterval = 1.0) async -> Bool {
        if let resolved = lock.withLock({ finished ? result : nil }) {
            return resolved
        }

        return await withCheckedContinuation { continuation in
            let resolved = lock.withLock { () -> Bool? in
                if finished {
                    return result
                }
                self.continuation = continuation
                return nil
            }

            if let resolved {
                continuation.resume(returning: resolved)
                return
            }

            let nanoseconds = UInt64(max(timeout, 0) * 1_000_000_000)
            Task { [weak self] in
                if nanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: nanoseconds)
                }
                self?.resolve(false)
            }
        }
    }

    private func resolve(_ value: Bool) {
        let resolution = lock.withLock { () -> (CheckedContinuation<Bool, Never>?, NSObjectProtocol?)? in
            guard finished == false else { return nil }
            finished = true
            result = value
            let continuationToResume = continuation
            continuation = nil
            let observerToRemove = observer
            observer = nil
            return (continuationToResume, observerToRemove)
        }

        guard let (continuationToResume, observerToRemove) = resolution else { return }
        if let observerToRemove {
            center.removeObserver(observerToRemove)
        }
        continuationToResume?.resume(returning: value)
    }
}

enum SpaceChangeVerifier {
    static func begin() -> SpaceChangeObserver {
        SpaceChangeObserver()
    }

    /// Wait for a Space change without using private Mission Control APIs.
    static func wait(timeout: TimeInterval = 1.0) async -> Bool {
        let observer = begin()
        return await observer.wait(timeout: timeout)
    }
}
