import Foundation
import SwiftUI

@MainActor
final class DesktopRecoveryCoordinator: ObservableObject {
    static let shared = DesktopRecoveryCoordinator()

    enum DisplayHealth: String, Equatable {
        case disconnected
        case connected
        case recovered

        var label: String {
            switch self {
            case .disconnected: return "Display disconnected"
            case .connected: return "Desktop connected"
            case .recovered: return "Desktop resumed"
            }
        }

        var systemImage: String {
            switch self {
            case .disconnected: return "display.trianglebadge.exclamationmark"
            case .connected: return "display.and.arrow.down"
            case .recovered: return "arrow.clockwise.heart"
            }
        }
    }

    struct Snapshot: Codable, Equatable {
        let version: Int
        let workspaceRawValue: String
        let savedAt: Date
        let windows: [DesktopFeatureState.SavedWindow]
        /// Optional for backwards compatibility with v1 snapshots.
        let activeWindowTitle: String?
    }

    private struct SnapshotContent: Equatable {
        let workspaceRawValue: String
        let windows: [DesktopFeatureState.SavedWindow]
        let activeWindowTitle: String?
    }

    @Published private(set) var displayHealth: DisplayHealth = .disconnected
    @Published private(set) var lastSnapshotDate: Date?
    @Published private(set) var recoveredAfterInterruption = false

    private let defaults: UserDefaults
    private let snapshotKey = "kamihi.desktop.recovery.v1"
    private let cleanExitKey = "kamihi.desktop.cleanExit.v1"
    private let autosaveMinimumInterval: TimeInterval = 0.75
    private var lastAutosaveDate: Date?
    private var pendingAutosaveTask: Task<Void, Never>?
    private var lastPersistedContent: SnapshotContent?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let existingSnapshot = Self.decodeSnapshot(defaults.data(forKey: snapshotKey))
        lastSnapshotDate = existingSnapshot?.savedAt
        if let existingSnapshot {
            lastPersistedContent = SnapshotContent(
                workspaceRawValue: existingSnapshot.workspaceRawValue,
                windows: existingSnapshot.windows,
                activeWindowTitle: existingSnapshot.activeWindowTitle
            )
        }
    }

    /// A connection is a resume boundary. If the process still owns windows, keep
    /// them exactly as-is. If iOS relaunched/evicted the app and memory is empty,
    /// restore the last durable snapshot even when the previous cable disconnect
    /// was clean. This is what makes the iPhone feel like one persistent computer.
    @discardableResult
    func prepareForConnection(desktop: DesktopSession) -> Bool {
        pendingAutosaveTask?.cancel()
        pendingAutosaveTask = nil

        let previousSessionWasClean = defaults.object(forKey: cleanExitKey) == nil || defaults.bool(forKey: cleanExitKey)
        let shouldRestore = desktop.windows.isEmpty
        let restored = shouldRestore && restoreSnapshot(desktop: desktop)

        recoveredAfterInterruption = restored && !previousSessionWasClean
        displayHealth = restored ? .recovered : .connected
        defaults.set(false, forKey: cleanExitKey)
        saveSnapshot(desktop: desktop, force: true)
        lastAutosaveDate = Date()
        return restored
    }

    func autosave(desktop: DesktopSession) {
        guard desktop.isExternalDisplayConnected else { return }

        let now = Date()
        let elapsed = lastAutosaveDate.map { now.timeIntervalSince($0) } ?? autosaveMinimumInterval
        if elapsed >= autosaveMinimumInterval {
            pendingAutosaveTask?.cancel()
            pendingAutosaveTask = nil
            saveSnapshot(desktop: desktop)
            lastAutosaveDate = now
            return
        }

        pendingAutosaveTask?.cancel()
        let remaining = max(0.10, autosaveMinimumInterval - elapsed)
        let delayNanoseconds = UInt64(remaining * 1_000_000_000)
        pendingAutosaveTask = Task { [weak self, weak desktop] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, let self, let desktop, desktop.isExternalDisplayConnected else { return }
            self.saveSnapshot(desktop: desktop)
            self.lastAutosaveDate = Date()
            self.pendingAutosaveTask = nil
        }
    }

    func finishSession(desktop: DesktopSession) {
        pendingAutosaveTask?.cancel()
        pendingAutosaveTask = nil
        saveSnapshot(desktop: desktop, force: true)
        DesktopFeatureState.shared.saveSession(desktop: desktop)
        lastAutosaveDate = Date()
        defaults.set(true, forKey: cleanExitKey)
        displayHealth = .disconnected
        recoveredAfterInterruption = false
    }

    func saveSnapshot(desktop: DesktopSession, force: Bool = false) {
        let workspaceRawValue = DesktopFeatureState.shared.workspace.rawValue
        let windows = Self.savedWindows(desktop: desktop)
        let activeWindowTitle = Self.activeWindowTitle(desktop: desktop)
        let content = SnapshotContent(
            workspaceRawValue: workspaceRawValue,
            windows: windows,
            activeWindowTitle: activeWindowTitle
        )

        guard force || content != lastPersistedContent else { return }

        let snapshot = Snapshot(
            version: 2,
            workspaceRawValue: workspaceRawValue,
            savedAt: Date(),
            windows: windows,
            activeWindowTitle: activeWindowTitle
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        lastPersistedContent = content
        lastSnapshotDate = snapshot.savedAt
    }

    @discardableResult
    func restoreSnapshot(desktop: DesktopSession) -> Bool {
        guard let snapshot = Self.decodeSnapshot(defaults.data(forKey: snapshotKey)), !snapshot.windows.isEmpty else {
            return false
        }

        desktop.closeAllDesktopWindows()
        var restoredActiveID: UUID?
        for item in snapshot.windows.prefix(12) {
            let id = desktop.openProductivityApp(
                item.title,
                frame: CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            )
            if let index = desktop.windows.firstIndex(where: { $0.id == id }) {
                desktop.windows[index].isMinimized = item.minimized
                desktop.windows[index].isMaximized = item.maximized
            }
            if item.title == snapshot.activeWindowTitle {
                restoredActiveID = id
            }
        }

        if let restoredActiveID,
           let active = desktop.windows.first(where: { $0.id == restoredActiveID }),
           !active.isMinimized {
            desktop.activate(restoredActiveID)
        } else {
            desktop.activeWindowID = desktop.windows.last(where: { !$0.isMinimized })?.id
        }

        if let workspace = DesktopFeatureState.Workspace(rawValue: snapshot.workspaceRawValue) {
            DesktopFeatureState.shared.workspace = workspace
            DesktopFeatureState.shared.focusMode = workspace == .focus
        }
        lastPersistedContent = SnapshotContent(
            workspaceRawValue: snapshot.workspaceRawValue,
            windows: snapshot.windows,
            activeWindowTitle: snapshot.activeWindowTitle
        )
        lastSnapshotDate = snapshot.savedAt
        return true
    }

    static func makeSnapshot(
        desktop: DesktopSession,
        workspace: DesktopFeatureState.Workspace,
        savedAt: Date = Date()
    ) -> Snapshot {
        Snapshot(
            version: 2,
            workspaceRawValue: workspace.rawValue,
            savedAt: savedAt,
            windows: savedWindows(desktop: desktop),
            activeWindowTitle: activeWindowTitle(desktop: desktop)
        )
    }

    static func decodeSnapshot(_ data: Data?) -> Snapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private static func activeWindowTitle(desktop: DesktopSession) -> String? {
        guard let id = desktop.activeWindowID else { return nil }
        return desktop.windows.first(where: { $0.id == id })?.title
    }

    private static func savedWindows(desktop: DesktopSession) -> [DesktopFeatureState.SavedWindow] {
        desktop.windows.map {
            DesktopFeatureState.SavedWindow(
                title: $0.title,
                x: $0.normalizedFrame.origin.x,
                y: $0.normalizedFrame.origin.y,
                width: $0.normalizedFrame.width,
                height: $0.normalizedFrame.height,
                minimized: $0.isMinimized,
                maximized: $0.isMaximized
            )
        }
    }
}
