import SwiftUI
import UIKit

/// Kamihi Desktop's semantic visual foundation. The app interiors and shell use
/// the same macOS 27-inspired hierarchy: uniform toolbars, edge-to-edge sidebars,
/// quiet separators, consistent radii and restrained SF typography. The visuals
/// remain original Kamihi UI built from public Apple platform components.
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
    static let toolbarHeight: CGFloat = 44
    static let compactToolbarHeight: CGFloat = 38
    static let sidebarWidth: CGFloat = 220
    static let chromeCornerRadius: CGFloat = 13
    static let windowCornerRadius: CGFloat = 13
    static let panelCornerRadius: CGFloat = 12
    static let minimumHitTarget: CGFloat = 44
    static let compactIcon: CGFloat = 16
    static let standardIcon: CGFloat = 19

    static func separatorOpacity(reduceTransparency: Bool, increasedContrast: Bool) -> Double {
        if increasedContrast { return 0.84 }
        return reduceTransparency ? 0.66 : 0.24
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
                        increasedContrast ? 0.78 : (reduceTransparency ? 0.58 : 0.22)
                    ),
                    lineWidth: DesktopShellMetrics.separatorWidth(
                        reduceTransparency: reduceTransparency,
                        increasedContrast: increasedContrast
                    )
                )
            }
            .shadow(color: Color.black.opacity(0.15), radius: 18, y: 9)
    }
}

/// Golden Gate-style app toolbar: one compact translucent plane with a single
/// bottom separator. Apps provide their own controls but no longer invent a
/// separate top-bar visual language.
private struct DesktopAppToolbarModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency || colorSchemeContrast == .increased {
                    DesktopShellPalette.secondaryCanvas
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesktopShellPalette.separator.opacity(colorSchemeContrast == .increased ? 0.62 : 0.20))
                    .frame(height: colorSchemeContrast == .increased ? 1 : 0.5)
                    .allowsHitTesting(false)
            }
    }
}

/// Edge-to-edge sidebar treatment used by Files, Notes, Documents and Settings.
private struct DesktopSidebarSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency || colorSchemeContrast == .increased {
                    DesktopShellPalette.secondaryCanvas
                } else {
                    ZStack {
                        Rectangle().fill(.thinMaterial)
                        Rectangle().fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.08)
                                : Color.white.opacity(0.10)
                        )
                    }
                }
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(DesktopShellPalette.separator.opacity(colorSchemeContrast == .increased ? 0.62 : 0.18))
                    .frame(width: colorSchemeContrast == .increased ? 1 : 0.5)
                    .allowsHitTesting(false)
            }
    }
}

private struct DesktopInsetPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesktopShellMetrics.panelCornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency || contrast == .increased {
                    shape.fill(DesktopShellPalette.secondaryCanvas)
                } else {
                    shape.fill(Color.primary.opacity(0.055))
                }
            }
            .overlay {
                shape.strokeBorder(
                    DesktopShellPalette.separator.opacity(contrast == .increased ? 0.54 : 0.16),
                    lineWidth: contrast == .increased ? 1 : 0.5
                )
            }
    }
}

/// Consistent icon-only toolbar affordance. The visible icon remains compact like
/// macOS while the hit target is still large enough for touch/trackpad use.
struct DesktopToolbarIconLabel: View {
    let systemImage: String
    let active: Bool

    init(_ systemImage: String, active: Bool = false) {
        self.systemImage = systemImage
        self.active = active
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.86))
            .frame(width: 30, height: 30)
            .background(
                active ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

extension View {
    func desktopShellChrome(cornerRadius: CGFloat = DesktopShellMetrics.chromeCornerRadius) -> some View {
        modifier(DesktopShellChromeModifier(cornerRadius: cornerRadius))
    }

    func desktopShellElevatedSurface(cornerRadius: CGFloat = DesktopShellMetrics.windowCornerRadius) -> some View {
        modifier(DesktopShellElevatedSurfaceModifier(cornerRadius: cornerRadius))
    }

    func desktopAppToolbar() -> some View {
        modifier(DesktopAppToolbarModifier())
    }

    func desktopSidebarSurface() -> some View {
        modifier(DesktopSidebarSurfaceModifier())
    }

    func desktopInsetPanel() -> some View {
        modifier(DesktopInsetPanelModifier())
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
        precondition(DesktopShellMetrics.toolbarHeight >= DesktopShellMetrics.compactToolbarHeight)
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
