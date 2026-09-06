import SwiftUI

public enum DesktopGlassStyle: String, CaseIterable, Identifiable {
    case soft
    case balanced
    case vivid

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .soft: return "Soft"
        case .balanced: return "Balanced"
        case .vivid: return "Vivid"
        }
    }
}

/// One persisted glass policy for the external desktop, launcher, dock, menu bar,
/// window chrome and Settings. Accessibility Reduce Transparency always wins.
@MainActor
public final class DesktopGlassAppearance: ObservableObject {
    public static let shared = DesktopGlassAppearance()

    @Published public var style: DesktopGlassStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "kamihi.desktop.glass.style") }
    }
    @Published public var highlightsEnabled: Bool {
        didSet { UserDefaults.standard.set(highlightsEnabled, forKey: "kamihi.desktop.glass.highlights") }
    }

    private init() {
        let defaults = UserDefaults.standard
        style = DesktopGlassStyle(rawValue: defaults.string(forKey: "kamihi.desktop.glass.style") ?? "") ?? .balanced
        highlightsEnabled = defaults.object(forKey: "kamihi.desktop.glass.highlights") as? Bool ?? true
    }

    var borderOpacity: Double {
        switch style {
        case .soft: return 0.16
        case .balanced: return 0.24
        case .vivid: return 0.34
        }
    }

    var highlightOpacity: Double {
        guard highlightsEnabled else { return 0 }
        switch style {
        case .soft: return 0.08
        case .balanced: return 0.14
        case .vivid: return 0.22
        }
    }

    var shadowOpacity: Double {
        switch style {
        case .soft: return 0.10
        case .balanced: return 0.18
        case .vivid: return 0.26
        }
    }
}

private struct DesktopGlassSurfaceModifier: ViewModifier {
    @ObservedObject private var appearance = DesktopGlassAppearance.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency || contrast == .increased {
                    shape.fill(KamihiTheme.Colors.secondarySurface)
                } else {
                    material(shape)
                }
            }
            .overlay {
                if !reduceTransparency && appearance.highlightsEnabled {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(appearance.highlightOpacity),
                                    Color.white.opacity(0.015),
                                    KamihiTheme.Colors.brandPurple.opacity(appearance.highlightOpacity * 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(contrast == .increased ? 0.54 : appearance.borderOpacity),
                    lineWidth: contrast == .increased ? 1.2 : 0.8
                )
                .allowsHitTesting(false)
            }
            .shadow(
                color: elevated ? Color.black.opacity(colorScheme == .dark ? appearance.shadowOpacity : appearance.shadowOpacity * 0.62) : .clear,
                radius: elevated ? 18 : 0,
                x: 0,
                y: elevated ? 9 : 0
            )
    }

    @ViewBuilder
    private func material(_ shape: RoundedRectangle) -> some View {
        switch appearance.style {
        case .soft:
            shape.fill(.thinMaterial)
        case .balanced:
            shape.fill(.regularMaterial)
        case .vivid:
            shape.fill(.ultraThinMaterial)
        }
    }
}

extension View {
    func desktopGlassSurface(cornerRadius: CGFloat = 20, elevated: Bool = true) -> some View {
        modifier(DesktopGlassSurfaceModifier(cornerRadius: cornerRadius, elevated: elevated))
    }
}
