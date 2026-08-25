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
        if let observer {
            center.removeObserver(observer)
        }
    }

    func wait(timeout: TimeInterval = 1.0) async -> Bool {
        lock.lock()
        if finished {
            let resolved = result
            lock.unlock()
            return resolved
        }
        lock.unlock()

        return await withCheckedContinuation { continuation in
            lock.lock()
            if finished {
                let resolved = result
                lock.unlock()
                continuation.resume(returning: resolved)
                return
            }
            self.continuation = continuation
            lock.unlock()

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
        let continuationToResume: CheckedContinuation<Bool, Never>?
        let observerToRemove: NSObjectProtocol?

        lock.lock()
        guard finished == false else {
            lock.unlock()
            return
        }
        finished = true
        result = value
        continuationToResume = continuation
        continuation = nil
        observerToRemove = observer
        observer = nil
        lock.unlock()

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
