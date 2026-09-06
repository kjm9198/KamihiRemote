import SwiftUI

public enum DesktopGlassStyle: String, CaseIterable, Identifiable {
    case soft
    case balanced
    case vivid

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .soft: return "Soft"
        case .balanced: return "macOS Glass"
        case .vivid: return "High Contrast Glass"
        }
    }
}

/// One persisted glass policy for the external desktop, Applications chooser,
/// Dock, menu bar, window chrome and Settings. Accessibility Reduce Transparency
/// and Increased Contrast always win over decorative translucency.
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
        case .soft: return 0.12
        case .balanced: return 0.20
        case .vivid: return 0.30
        }
    }

    var highlightOpacity: Double {
        guard highlightsEnabled else { return 0 }
        switch style {
        case .soft: return 0.06
        case .balanced: return 0.13
        case .vivid: return 0.20
        }
    }

    var shadowOpacity: Double {
        switch style {
        case .soft: return 0.10
        case .balanced: return 0.16
        case .vivid: return 0.23
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
                                    Color.white.opacity(0.014),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(contrast == .increased ? 0.50 : appearance.borderOpacity),
                    lineWidth: contrast == .increased ? 1.1 : 0.7
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if !reduceTransparency && appearance.highlightsEnabled {
                    Rectangle()
                        .fill(Color.white.opacity(appearance.highlightOpacity * 0.72))
                        .frame(height: 0.7)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: elevated
                    ? Color.black.opacity(colorScheme == .dark ? appearance.shadowOpacity : appearance.shadowOpacity * 0.70)
                    : .clear,
                radius: elevated ? 20 : 0,
                x: 0,
                y: elevated ? 10 : 0
            )
    }

    @ViewBuilder
    private func material(_ shape: RoundedRectangle) -> some View {
        switch appearance.style {
        case .soft:
            shape.fill(.thinMaterial)
        case .balanced:
            shape.fill(.ultraThinMaterial)
        case .vivid:
            shape.fill(.regularMaterial)
        }
    }
}

extension View {
    func desktopGlassSurface(cornerRadius: CGFloat = 14, elevated: Bool = true) -> some View {
        modifier(DesktopGlassSurfaceModifier(cornerRadius: cornerRadius, elevated: elevated))
    }
}
