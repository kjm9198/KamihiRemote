import SwiftUI
import UIKit

/// Kamihi Desktop's semantic visual foundation. The shell now follows a
/// macOS-inspired hierarchy: compact chrome, frosted materials, quiet separators,
/// centered window titles and restrained system typography while remaining native
/// SwiftUI and accessible on iPhone-driven external displays.
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
    static let compactSpacing: CGFloat = 7
    static let standardSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 16
    static let chromeCornerRadius: CGFloat = 14
    static let windowCornerRadius: CGFloat = 14
    static let minimumHitTarget: CGFloat = 44
    static let compactIcon: CGFloat = 16
    static let standardIcon: CGFloat = 19

    static func separatorOpacity(reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if increasedContrast { return 0.84 }
        return reduceTransparency ? 0.66 : 0.28
    }

    static func separatorWidth(reduceTransparency: Bool, increasedContrast: Bool) -> CGFloat {
        (reduceTransparency || increasedContrast) ? 1 : 0.5
    }
}

enum DesktopShellPalette {
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
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    var cornerRadius: CGFloat = DesktopShellMetrics.chromeCornerRadius

    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency || increasedContrast {
                    shape.fill(DesktopShellPalette.secondaryCanvas)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.stroke(
                    DesktopShellPalette.separator.opacity(
                        DesktopShellMetrics.separatorOpacity(
                            reduceTransparency: reduceTransparency,
                            increasedContrast: increasedContrast
                        )
                    ),
                    lineWidth: DesktopShellMetrics.separatorWidth(
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increasedContrast
                    )
                )
            }
            .overlay(alignment: .top) {
                if !reduceTransparency && !increasedContrast {
                    shape
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
                        .mask(
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
    }
}

struct DesktopShellElevatedSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    var cornerRadius: CGFloat = DesktopShellMetrics.windowCornerRadius

    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency || increasedContrast {
                    shape.fill(DesktopShellPalette.canvas)
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay {
                shape.stroke(
                    DesktopShellPalette.separator.opacity(
                        increasedContrast ? 0.78 : (reduceTransparency ? 0.58 : 0.24)
                    ),
                    lineWidth: DesktopShellMetrics.separatorWidth(
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increasedContrast
                    )
                )
            }
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 9)
    }
}

extension View {
    func desktopShellChrome(cornerRadius: CGFloat = DesktopShellMetrics.chromeCornerRadius) -> some View {
        modifier(DesktopShellChromeModifier(cornerRadius: cornerRadius))
    }

    func desktopShellElevatedSurface(cornerRadius: CGFloat = DesktopShellMetrics.windowCornerRadius) -> some View {
        modifier(DesktopShellElevatedSurfaceModifier(cornerRadius: cornerRadius))
    }

    @MainActor
    func desktopShellTheme(_ appearance: DesktopShellAppearance) -> some View {
        preferredColorScheme(appearance.theme.preferredColorScheme)
    }

    @MainActor
    func desktopShellTheme() -> some View {
        preferredColorScheme(DesktopShellAppearance.shared.theme.preferredColorScheme)
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
        precondition(
            DesktopShellMetrics.separatorOpacity(reduceTransparency: false, increasedContrast: true)
                > DesktopShellMetrics.separatorOpacity(reduceTransparency: false, increasedContrast: false)
        )
        precondition(
            DesktopShellMetrics.separatorWidth(reduceTransparency: false, increasedContrast: true)
                >= DesktopShellMetrics.separatorWidth(reduceTransparency: false, increasedContrast: false)
        )
        print("[DesktopShellDesignSystemSelfCheck] PASS")
    }
}
#endif
