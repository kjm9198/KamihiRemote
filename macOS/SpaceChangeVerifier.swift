import AppKit
import Foundation

final class SpaceChangeObserver {
    private var finished = false
    private let center = NSWorkspace.shared.notificationCenter
    private var observer: NSObjectProtocol?
    private var continuation: CheckedContinuation<Bool, Never>?

    init() {
        observer = center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.finished == false else { return }
                self.finished = true
                if let obs = self.observer { self.center.removeObserver(obs) }
                self.continuation?.resume(returning: true)
                self.continuation = nil
            }
        }
    }

    func wait(timeout: TimeInterval = 1.0) async -> Bool {
        if finished { return true }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self, self.finished == false else { return }
                self.finished = true
                if let obs = self.observer { self.center.removeObserver(obs) }
                self.continuation?.resume(returning: false)
                self.continuation = nil
            }
        }
    }
}

enum SpaceChangeVerifier {
    static func begin() -> SpaceChangeObserver {
        SpaceChangeObserver()
    }

    /// Wait for a Space change without using private Mission Control APIs.
    static func wait(timeout: TimeInterval = 1.0) async -> Bool {
        let obs = begin()
        return await obs.wait(timeout: timeout)
    }
}
