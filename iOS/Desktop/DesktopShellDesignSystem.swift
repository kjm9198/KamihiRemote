import SwiftUI
import UIKit

/// Kamihi Desktop's semantic visual foundation. This intentionally follows
/// public iOS/iPadOS conventions (semantic colors, materials, SF Symbols)
/// without copying macOS or Samsung trade dress.
@MainActor
final class DesktopShellAppearance: ObservableObject {
    static let shared = DesktopShellAppearance()

    enum Theme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var icon: String {
            switch self {
            case .system: "circle.lefthalf.filled"
            case .light: "sun.max.fill"
            case .dark: "moon.fill"
            }
        }

        var preferredColorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    @Published var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let theme = "kamihi.desktop.shell.theme.v1"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.theme)
        self.theme = Theme(rawValue: stored ?? "") ?? .system
    }
}

enum DesktopShellMetrics {
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
    static let chromeCornerRadius: CGFloat = 18
    static let windowCornerRadius: CGFloat = 20
    static let minimumHitTarget: CGFloat = 44
    static let compactIcon: CGFloat = 17
    static let standardIcon: CGFloat = 20
}

enum DesktopShellPalette {
    /// Semantic base canvas that automatically tracks light/dark appearance.
    static let canvas = Color(uiColor: .systemBackground)
    static let secondaryCanvas = Color(uiColor: .secondarySystemBackground)
    static let elevatedCanvas = Color(uiColor: .tertiarySystemBackground)
    static let separator = Color(uiColor: .separator)
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let accent = Color.accentColor
}

struct DesktopShellChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = DesktopShellMetrics.chromeCornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DesktopShellPalette.secondaryCanvas)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        DesktopShellPalette.separator.opacity(reduceTransparency ? 0.72 : 0.45),
                        lineWidth: reduceTransparency ? 1 : 0.5
                    )
            }
    }
}

struct DesktopShellElevatedSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = DesktopShellMetrics.windowCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                reduceTransparency ? DesktopShellPalette.canvas : DesktopShellPalette.secondaryCanvas,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        DesktopShellPalette.separator.opacity(reduceTransparency ? 0.62 : 0.35),
                        lineWidth: reduceTransparency ? 1 : 0.5
                    )
            }
    }
}

extension View {
    func desktopShellChrome(cornerRadius: CGFloat = DesktopShellMetrics.chromeCornerRadius) -> some View {
        modifier(DesktopShellChromeModifier(cornerRadius: cornerRadius))
    }

    func desktopShellElevatedSurface(cornerRadius: CGFloat = DesktopShellMetrics.windowCornerRadius) -> some View {
        modifier(DesktopShellElevatedSurfaceModifier(cornerRadius: cornerRadius))
    }

    func desktopShellTheme(_ appearance: DesktopShellAppearance = .shared) -> some View {
        preferredColorScheme(appearance.theme.preferredColorScheme)
    }
}

#if DEBUG
enum DesktopShellDesignSystemSelfCheck {
    static func run() {
        precondition(DesktopShellMetrics.minimumHitTarget >= 44)
        precondition(Set(DesktopShellAppearance.Theme.allCases.map(\.rawValue)).count == 3)
        precondition(DesktopShellAppearance.Theme.system.preferredColorScheme == nil)
        precondition(DesktopShellMetrics.chromeCornerRadius > 0)
        precondition(DesktopShellMetrics.windowCornerRadius >= DesktopShellMetrics.chromeCornerRadius)
        print("[DesktopShellDesignSystemSelfCheck] PASS")
    }
}
#endif
