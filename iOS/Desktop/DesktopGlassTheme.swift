import SwiftUI

public enum DesktopGlassStyle: String, CaseIterable, Identifiable {
    case soft
    case balanced
    case vivid

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .soft: return "Soft"
        case .balanced: return "Golden Gate"
        case .vivid: return "High Contrast"
        }
    }
}

/// One persisted glass policy for the external desktop, Applications chooser,
/// Dock, menu bar, window chrome and Settings. The continuous clarity control
/// mirrors the macOS 27 idea of letting people move from a clearer glass surface
/// toward a more tinted, legible one without changing every app independently.
/// Accessibility Reduce Transparency and Increased Contrast always win.
@MainActor
public final class DesktopGlassAppearance: ObservableObject {
    public static let shared = DesktopGlassAppearance()

    @Published public var style: DesktopGlassStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "kamihi.desktop.glass.style") }
    }
    @Published public var highlightsEnabled: Bool {
        didSet { UserDefaults.standard.set(highlightsEnabled, forKey: "kamihi.desktop.glass.highlights") }
    }
    /// 0 = strongly tinted/diffused, 1 = clearest supported desktop glass.
    @Published public var clarity: Double {
        didSet {
            let bounded = min(max(clarity, 0), 1)
            if bounded != clarity {
                clarity = bounded
                return
            }
            UserDefaults.standard.set(bounded, forKey: "kamihi.desktop.glass.clarity.v1")
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        style = DesktopGlassStyle(rawValue: defaults.string(forKey: "kamihi.desktop.glass.style") ?? "") ?? .balanced
        highlightsEnabled = defaults.object(forKey: "kamihi.desktop.glass.highlights") as? Bool ?? true
        clarity = defaults.object(forKey: "kamihi.desktop.glass.clarity.v1") as? Double ?? 0.62
    }

    var borderOpacity: Double {
        let base: Double
        switch style {
        case .soft: base = 0.11
        case .balanced: base = 0.18
        case .vivid: base = 0.28
        }
        return min(0.42, base + (1 - clarity) * 0.08)
    }

    var highlightOpacity: Double {
        guard highlightsEnabled else { return 0 }
        let base: Double
        switch style {
        case .soft: base = 0.055
        case .balanced: base = 0.12
        case .vivid: base = 0.18
        }
        return min(0.28, base + clarity * 0.055)
    }

    var shadowOpacity: Double {
        let base: Double
        switch style {
        case .soft: base = 0.10
        case .balanced: base = 0.16
        case .vivid: base = 0.23
        }
        return min(0.32, base + (1 - clarity) * 0.035)
    }

    /// Golden Gate's clearer end still needs diffusion over busy wallpaper.
    var tintOpacity: Double {
        0.035 + (1 - clarity) * 0.16
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
                        .overlay {
                            shape.fill(
                                (colorScheme == .dark ? Color.black : Color.white)
                                    .opacity(appearance.tintOpacity)
                            )
                        }
                }
            }
            .overlay {
                if !reduceTransparency && appearance.highlightsEnabled {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(appearance.highlightOpacity),
                                    Color.white.opacity(0.012),
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
