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
            case .recovered: return "Desktop recovered"
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
    }

    @Published private(set) var displayHealth: DisplayHealth = .disconnected
    @Published private(set) var lastSnapshotDate: Date?
    @Published private(set) var recoveredAfterInterruption = false

    private let defaults: UserDefaults
    private let snapshotKey = "kamihi.desktop.recovery.v1"
    private let cleanExitKey = "kamihi.desktop.cleanExit.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastSnapshotDate = Self.decodeSnapshot(defaults.data(forKey: snapshotKey))?.savedAt
    }

    @discardableResult
    func prepareForConnection(desktop: DesktopSession) -> Bool {
        let previousSessionWasClean = defaults.object(forKey: cleanExitKey) == nil || defaults.bool(forKey: cleanExitKey)
        let restored = !previousSessionWasClean && restoreSnapshot(desktop: desktop)
        recoveredAfterInterruption = restored
        displayHealth = restored ? .recovered : .connected
        defaults.set(false, forKey: cleanExitKey)
        saveSnapshot(desktop: desktop)
        return restored
    }

    func autosave(desktop: DesktopSession) {
        guard desktop.isExternalDisplayConnected else { return }
        saveSnapshot(desktop: desktop)
    }

    func finishSession(desktop: DesktopSession) {
        saveSnapshot(desktop: desktop)
        defaults.set(true, forKey: cleanExitKey)
        displayHealth = .disconnected
        recoveredAfterInterruption = false
    }

    func saveSnapshot(desktop: DesktopSession) {
        let snapshot = Self.makeSnapshot(desktop: desktop, workspace: DesktopFeatureState.shared.workspace)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        lastSnapshotDate = snapshot.savedAt
    }

    @discardableResult
    func restoreSnapshot(desktop: DesktopSession) -> Bool {
        guard let snapshot = Self.decodeSnapshot(defaults.data(forKey: snapshotKey)), !snapshot.windows.isEmpty else {
            return false
        }

        desktop.closeAllDesktopWindows()
        for item in snapshot.windows.prefix(8) {
            let id = desktop.openProductivityApp(
                item.title,
                frame: CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            )
            if let index = desktop.windows.firstIndex(where: { $0.id == id }) {
                desktop.windows[index].isMinimized = item.minimized
                desktop.windows[index].isMaximized = item.maximized
            }
        }
        if let workspace = DesktopFeatureState.Workspace(rawValue: snapshot.workspaceRawValue) {
            DesktopFeatureState.shared.workspace = workspace
            DesktopFeatureState.shared.focusMode = workspace == .focus
        }
        lastSnapshotDate = snapshot.savedAt
        return true
    }

    static func makeSnapshot(
        desktop: DesktopSession,
        workspace: DesktopFeatureState.Workspace,
        savedAt: Date = Date()
    ) -> Snapshot {
        Snapshot(
            version: 1,
            workspaceRawValue: workspace.rawValue,
            savedAt: savedAt,
            windows: desktop.windows.map {
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
        )
    }

    static func decodeSnapshot(_ data: Data?) -> Snapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
