import SwiftUI
import UIKit

@MainActor
final class DesktopFeatureState: ObservableObject {
    static let shared = DesktopFeatureState()

    enum Workspace: String, CaseIterable, Identifiable {
        case vibe = "Vibe"
        case work = "Work"
        case study = "Study"
        case entertainment = "Entertainment"
        case focus = "Focus"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .vibe: return "sparkles.rectangle.stack"
            case .work: return "briefcase.fill"
            case .study: return "book.fill"
            case .entertainment: return "play.tv.fill"
            case .focus: return "scope"
            }
        }
    }

    struct SavedWindow: Codable, Equatable {
        var title: String
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var minimized: Bool
        var maximized: Bool
    }

    @Published var workspace: Workspace = .vibe
    @Published var focusMode = false
    @Published var privacyMode = false
    @Published var showCommandCenter = false
    @Published var showQuickSettings = false
    @Published var showDisplayDiagnostics = false
    @Published var uiScale: Double
    @Published var cursorScale: Double
    @Published var animationIntensity: Double
    @Published var batterySaverOverride: Bool

    private let defaults = UserDefaults.standard
    private let restorationKey = "kamihi.desktop.restoration.v1"

    private init() {
        uiScale = defaults.object(forKey: "kamihi.desktop.uiScale") as? Double ?? 1.0
        cursorScale = defaults.object(forKey: "kamihi.desktop.cursorScale") as? Double ?? 1.0
        animationIntensity = defaults.object(forKey: "kamihi.desktop.animationIntensity") as? Double ?? 1.0
        batterySaverOverride = defaults.bool(forKey: "kamihi.desktop.batterySaverOverride")
    }

    var shouldConserveEnergy: Bool {
        batterySaverOverride || ProcessInfo.processInfo.isLowPowerModeEnabled || DesktopPowerMonitor.shared.thermalState >= .serious
    }

    func setWorkspace(_ workspace: Workspace, desktop: DesktopSession) {
        self.workspace = workspace
        focusMode = workspace == .focus

        switch workspace {
        case .vibe:
            desktop.openVibeWorkspace()
        case .work:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp("ChatGPT", frame: CGRect(x: 0.012, y: 0.055, width: 0.49, height: 0.835))
            _ = desktop.openProductivityApp("Browser", frame: CGRect(x: 0.51, y: 0.055, width: 0.478, height: 0.50))
            _ = desktop.openProductivityApp("Notes", frame: CGRect(x: 0.51, y: 0.565, width: 0.478, height: 0.325))
        case .study:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp("YouTube", frame: CGRect(x: 0.012, y: 0.055, width: 0.56, height: 0.835))
            _ = desktop.openProductivityApp("Notes", frame: CGRect(x: 0.582, y: 0.055, width: 0.406, height: 0.835))
        case .entertainment:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp("YouTube", frame: CGRect(x: 0.03, y: 0.07, width: 0.94, height: 0.79))
        case .focus:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp("ChatGPT", frame: CGRect(x: 0.08, y: 0.07, width: 0.84, height: 0.79))
        }
        saveSession(desktop: desktop)
    }

    func saveSession(desktop: DesktopSession) {
        let windows = desktop.windows.map {
            SavedWindow(
                title: $0.title,
                x: $0.normalizedFrame.origin.x,
                y: $0.normalizedFrame.origin.y,
                width: $0.normalizedFrame.width,
                height: $0.normalizedFrame.height,
                minimized: $0.isMinimized,
                maximized: $0.isMaximized
            )
        }
        if let data = try? JSONEncoder().encode(windows) {
            defaults.set(data, forKey: restorationKey)
        }
    }

    @discardableResult
    func restoreSession(desktop: DesktopSession) -> Bool {
        guard let data = defaults.data(forKey: restorationKey),
              let saved = try? JSONDecoder().decode([SavedWindow].self, from: data),
              !saved.isEmpty else { return false }

        desktop.closeAllDesktopWindows()
        for item in saved.prefix(8) {
            let id = desktop.openProductivityApp(
                item.title,
                frame: CGRect(x: item.x, y: item.y, width: item.width, height: item.height)
            )
            if let index = desktop.windows.firstIndex(where: { $0.id == id }) {
                desktop.windows[index].isMinimized = item.minimized
                desktop.windows[index].isMaximized = item.maximized
            }
        }
        return true
    }

    func persistPreferences() {
        defaults.set(uiScale, forKey: "kamihi.desktop.uiScale")
        defaults.set(cursorScale, forKey: "kamihi.desktop.cursorScale")
        defaults.set(animationIntensity, forKey: "kamihi.desktop.animationIntensity")
        defaults.set(batterySaverOverride, forKey: "kamihi.desktop.batterySaverOverride")
    }
}

@MainActor
extension DesktopSession {
    func closeAllDesktopWindows() {
        windows.removeAll()
        activeWindowID = nil
    }

    func cycleWindow(forward: Bool = true) {
        let visible = windows.filter { !$0.isMinimized }
        guard !visible.isEmpty else { return }
        guard let activeWindowID,
              let current = visible.firstIndex(where: { $0.id == activeWindowID }) else {
            activate(visible.last!.id)
            return
        }
        let next = forward
            ? (current + 1) % visible.count
            : (current - 1 + visible.count) % visible.count
        activate(visible[next].id)
    }

    func snapActiveTopLeft() { setActiveFrame(CGRect(x: 0.012, y: 0.055, width: 0.482, height: 0.407)) }
    func snapActiveTopRight() { setActiveFrame(CGRect(x: 0.506, y: 0.055, width: 0.482, height: 0.407)) }
    func snapActiveBottomLeft() { setActiveFrame(CGRect(x: 0.012, y: 0.473, width: 0.482, height: 0.417)) }
    func snapActiveBottomRight() { setActiveFrame(CGRect(x: 0.506, y: 0.473, width: 0.482, height: 0.417)) }

    func snapActiveThird(_ third: Int) {
        let index = min(max(third, 0), 2)
        let gap: CGFloat = 0.009
        let width: CGFloat = (0.976 - gap * 2) / 3
        setActiveFrame(CGRect(x: 0.012 + CGFloat(index) * (width + gap), y: 0.055, width: width, height: 0.835))
    }

    private func setActiveFrame(_ frame: CGRect) {
        guard let id = activeWindowID, let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMaximized = false
        windows[index].isMinimized = false
        windows[index].normalizedFrame = frame
    }
}

@MainActor
final class DesktopPowerMonitor: ObservableObject {
    static let shared = DesktopPowerMonitor()

    @Published private(set) var batteryLevel: Float = -1
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var observers: [NSObjectProtocol] = []

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        thermalState = ProcessInfo.processInfo.thermalState
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var batteryPercentageText: String {
        batteryLevel >= 0 ? "\(Int(batteryLevel * 100))%" : "--"
    }

    var thermalText: String {
        switch thermalState {
        case .nominal: return "Cool"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

@MainActor
final class DesktopClipboardStore: ObservableObject {
    static let shared = DesktopClipboardStore()

    @Published private(set) var items: [String] = []
    private var lastChangeCount = UIPasteboard.general.changeCount

    private init() {}

    func captureIfChanged() {
        let board = UIPasteboard.general
        guard board.changeCount != lastChangeCount else { return }
        lastChangeCount = board.changeCount
        guard let value = board.string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        items.removeAll { $0 == value }
        items.insert(value, at: 0)
        if items.count > 20 { items.removeLast(items.count - 20) }
    }

    func copy(_ value: String) {
        UIPasteboard.general.string = value
        captureIfChanged()
    }

    func clear() { items.removeAll() }
}

@MainActor
final class DesktopFocusTimer: ObservableObject {
    static let shared = DesktopFocusTimer()

    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    private var timer: Timer?

    private init() {}

    func start(minutes: Int = 25) {
        stop()
        remainingSeconds = max(1, minutes) * 60
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 { self.stop() }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = max(remainingSeconds, 0)
    }

    func reset() {
        stop()
        remainingSeconds = 0
    }

    var formatted: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }
}

struct DesktopCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let keywords: [String]
    let action: @MainActor (DesktopSession) -> Void

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return title.lowercased().contains(q) || subtitle.lowercased().contains(q) || keywords.contains { $0.lowercased().contains(q) }
    }
}

@MainActor
enum DesktopCommandCatalog {
    static var commands: [DesktopCommand] {
        [
            DesktopCommand(id: "vibe", title: "Open Vibe Workspace", subtitle: "ChatGPT, YouTube and Notes", icon: "sparkles.rectangle.stack", keywords: ["code", "ai", "workspace"]) { DesktopFeatureState.shared.setWorkspace(.vibe, desktop: $0) },
            DesktopCommand(id: "chatgpt", title: "Open ChatGPT", subtitle: "AI and vibe coding", icon: "sparkles", keywords: ["ai", "chat"]) { $0.openChatGPT() },
            DesktopCommand(id: "youtube", title: "Open YouTube", subtitle: "Video and tutorials", icon: "play.rectangle.fill", keywords: ["video", "music"]) { $0.openYouTube() },
            DesktopCommand(id: "notes", title: "Open Notes", subtitle: "Quick local notes", icon: "note.text", keywords: ["write", "text"]) { $0.openNotes() },
            DesktopCommand(id: "browser", title: "Open Browser", subtitle: "Desktop WebKit browser", icon: "safari", keywords: ["web", "internet"]) { $0.openBrowser() },
            DesktopCommand(id: "split-left", title: "Snap Left", subtitle: "Move active window to left half", icon: "rectangle.lefthalf.inset.filled", keywords: ["window", "split"]) { $0.snapActiveLeft() },
            DesktopCommand(id: "split-right", title: "Snap Right", subtitle: "Move active window to right half", icon: "rectangle.righthalf.inset.filled", keywords: ["window", "split"]) { $0.snapActiveRight() },
            DesktopCommand(id: "cycle", title: "Next Window", subtitle: "Cycle active window", icon: "rectangle.on.rectangle", keywords: ["switch", "tab"]) { $0.cycleWindow() },
            DesktopCommand(id: "focus", title: "Focus Workspace", subtitle: "One distraction-free ChatGPT window", icon: "scope", keywords: ["focus", "clean"]) { DesktopFeatureState.shared.setWorkspace(.focus, desktop: $0) },
            DesktopCommand(id: "save", title: "Save Workspace", subtitle: "Remember window positions", icon: "square.and.arrow.down", keywords: ["restore", "session"]) { DesktopFeatureState.shared.saveSession(desktop: $0) }
        ]
    }
}

struct DesktopDisplayMetrics: Equatable {
    let size: CGSize
    let scale: CGFloat

    var aspectRatio: CGFloat { size.height == 0 ? 0 : size.width / size.height }
    var classification: String {
        if aspectRatio > 2.0 { return "Ultrawide" }
        if aspectRatio > 1.70 { return "16:9 / glasses" }
        if aspectRatio > 1.45 { return "16:10" }
        return "Compact"
    }

    var recommendedScale: Double {
        if size.width <= 1280 { return 1.1 }
        if size.width >= 3000 { return 1.25 }
        return 1.0
    }
}
