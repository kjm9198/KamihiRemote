import Foundation
import CoreGraphics

/// User-facing ways to enter Kamihi Desktop.
/// These are startup layouts, not separate products: once inside, every app remains available.
public enum DesktopLaunchProfile: String, CaseIterable, Identifiable, Codable {
    case clean
    case resume
    case work
    case browse
    case media
    case vibe

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clean: return "Clean Desktop"
        case .resume: return "Resume"
        case .work: return "Work"
        case .browse: return "Browse"
        case .media: return "Media"
        case .vibe: return "Vibe"
        }
    }

    public var subtitle: String {
        switch self {
        case .clean: return "Start with an empty iOS-style desktop and open anything you want."
        case .resume: return "Restore the windows and layout from your last desktop session."
        case .work: return "Start with a practical work layout, then rearrange it however you like."
        case .browse: return "Open a full-size browser first for everyday web use."
        case .media: return "Open media first for video, streaming, and entertainment."
        case .vibe: return "Optional ChatGPT, YouTube, and Notes workspace."
        }
    }

    public var systemImage: String {
        switch self {
        case .clean: return "rectangle.inset.filled"
        case .resume: return "arrow.counterclockwise.circle"
        case .work: return "briefcase"
        case .browse: return "safari"
        case .media: return "play.rectangle"
        case .vibe: return "sparkles.rectangle.stack"
        }
    }

    private static let defaultsKey = "kamihi.desktop.launchProfile"

    public static var selected: DesktopLaunchProfile {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let profile = DesktopLaunchProfile(rawValue: raw) else { return .clean }
            return profile
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    @MainActor
    public func apply(to desktop: DesktopSession) {
        switch self {
        case .clean:
            desktop.closeAllDesktopWindows()
        case .resume:
            if !DesktopFeatureState.shared.restoreSession(desktop: desktop) {
                desktop.closeAllDesktopWindows()
            }
        case .work:
            DesktopFeatureState.shared.setWorkspace(.work, desktop: desktop)
        case .browse:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp(
                "Browser",
                frame: CGRect(x: 0.025, y: 0.055, width: 0.95, height: 0.835)
            )
        case .media:
            desktop.closeAllDesktopWindows()
            _ = desktop.openProductivityApp(
                "YouTube",
                frame: CGRect(x: 0.025, y: 0.055, width: 0.95, height: 0.835)
            )
        case .vibe:
            DesktopFeatureState.shared.setWorkspace(.vibe, desktop: desktop)
        }
    }
}
