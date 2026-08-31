import Foundation

/// Defines the top-level product mode selected by the user.
public enum AppMode: String, CaseIterable, Identifiable, Codable {
    case none
    case remoteMac
    case externalDesktop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Mode Chooser"
        case .remoteMac: return "Remote for Mac"
        case .externalDesktop: return "Kamihi Desktop"
        }
    }

    public var subtitle: String {
        switch self {
        case .none: return "Choose your product experience"
        case .remoteMac: return "Control your MacBook from your iPhone"
        case .externalDesktop: return "Turn an external display into your workspace"
        }
    }

    public var systemImage: String {
        switch self {
        case .none: return "square.grid.2x2"
        case .remoteMac: return "laptopcomputer.and.iphone"
        case .externalDesktop: return "display.2"
        }
    }

    /// Evaluates debug launch arguments to determine initial mode.
    public static func initialModeFromArguments() -> (mode: AppMode, isLab: Bool) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-KamihiDesktopLab") {
            return (.externalDesktop, true)
        }
        if args.contains("-KamihiModeRemote") ||
           args.contains("-pairingCode") ||
           args.contains("-hostAddress") ||
           args.contains("-KamihiUITestTab") ||
           args.contains("-KamihiUITestDeckGallery") {
            return (.remoteMac, false)
        }
        if args.contains("-KamihiModeDesktop") {
            return (.externalDesktop, false)
        }
        if args.contains("-KamihiModeChooser") {
            return (.none, false)
        }
        return (.none, false)
    }
}
