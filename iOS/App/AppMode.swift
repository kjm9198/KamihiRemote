import Foundation

/// Kamihi Desktop has one product experience: the iPhone-powered external desktop.
public enum AppMode: String, CaseIterable, Identifiable, Codable {
    case none
    case externalDesktop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Startup Profiles"
        case .externalDesktop: return "Kamihi Desktop"
        }
    }

    public var subtitle: String {
        switch self {
        case .none: return "Choose how Kamihi Desktop should start"
        case .externalDesktop: return "Turn an external display into your iPhone-powered workspace"
        }
    }

    public var systemImage: String {
        switch self {
        case .none: return "rectangle.grid.2x2"
        case .externalDesktop: return "display.2"
        }
    }

    /// Debug launch arguments may open Desktop Lab directly; all other launches
    /// start at the Kamihi Desktop startup-profile picker.
    public static func initialModeFromArguments() -> (mode: AppMode, isLab: Bool) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-KamihiDesktopLab") {
            return (.externalDesktop, true)
        }
        if args.contains("-KamihiModeDesktop") {
            return (.externalDesktop, false)
        }
        return (.none, false)
    }
}
