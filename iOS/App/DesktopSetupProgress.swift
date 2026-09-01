import Foundation

/// Setup completion records the guide, never a claim that hardware was tested.
/// Uses an injectable defaults store so regression tests cannot alter user settings.
enum DesktopSetupStep: String, CaseIterable, Identifiable {
    case welcome, connection, input, display, privacy, ready

    var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var title: String {
        switch self {
        case .welcome: return "Meet your desktop"
        case .connection: return "Connect a display"
        case .input: return "Make yourself comfortable"
        case .display: return "Fit your screen"
        case .privacy: return "Keep your phone close"
        case .ready: return "Choose your starting point"
        }
    }
}

struct DesktopSetupProgress {
    static let version = 1
    static let completedKey = "kamihi.desktop.setup.completedVersion"
    static let stepKey = "kamihi.desktop.setup.step"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isComplete: Bool { defaults.integer(forKey: Self.completedKey) >= Self.version }
    var step: DesktopSetupStep {
        get { DesktopSetupStep(rawValue: defaults.string(forKey: Self.stepKey) ?? "") ?? .welcome }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.stepKey) }
    }

    func advance() {
        let next = min(step.index + 1, DesktopSetupStep.allCases.count - 1)
        step = DesktopSetupStep.allCases[next]
    }

    func goBack() {
        step = DesktopSetupStep.allCases[max(step.index - 1, 0)]
    }

    /// A review does not revoke a previously completed setup or reset app data.
    func beginReview() { step = .welcome }

    @discardableResult
    func finish() -> Bool {
        guard step == .ready else { return false }
        defaults.set(max(Self.version, defaults.integer(forKey: Self.completedKey)), forKey: Self.completedKey)
        step = .welcome
        return true
    }
}
