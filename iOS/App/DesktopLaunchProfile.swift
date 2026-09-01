import Foundation
import CoreGraphics

/// User-facing ways to enter Kamihi Desktop.
/// Profiles prioritize the launcher rather than silently opening applications.
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
        case .work: return "Start clean with Notes, Files, and work tools surfaced first in the launcher."
        case .browse: return "Start clean with Browser surfaced first; nothing opens until you choose it."
        case .media: return "Start clean with YouTube and media apps surfaced first in the launcher."
        case .vibe: return "Optional ChatGPT, YouTube, and Notes shortcuts without auto-opening them."
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

    /// Launcher ordering keeps profiles useful while preserving a calm empty desktop.
    public var preferredAppOrder: [String] {
        switch self {
        case .clean, .resume:
            return []
        case .work:
            return ["Notes", "Files", "Browser", "Calculator", "Clipboard"]
        case .browse:
            return ["Browser", "ChatGPT", "Files"]
        case .media:
            return ["YouTube", "Photos", "Browser"]
        case .vibe:
            return ["ChatGPT", "YouTube", "Notes", "Browser"]
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
    func apply(to desktop: DesktopSession) {
        switch self {
        case .resume:
            if !DesktopFeatureState.shared.restoreSession(desktop: desktop) {
                desktop.closeAllDesktopWindows()
            }
        case .clean, .work, .browse, .media, .vibe:
            // Profiles influence launcher priority only. Apps never turn
            // themselves on just because a display was connected.
            desktop.closeAllDesktopWindows()
        }
    }
}
