import SwiftUI

/// Renders the software cursor on Kamihi Desktop.
/// The default Kamihi Dot intentionally behaves more like an iPadOS pointer:
/// compact at rest, tactile on click, and contextual for drag/resize states.
struct DesktopCursorView: View {
    var cursorPosition: CGPoint
    var cursorStyle: CursorStyle = .kamihiDot
    var interactionState: CursorInteractionState = .defaultState
    var cursorScale: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GeometryReader { geo in
            let x = cursorPosition.x * geo.size.width
            let y = cursorPosition.y * geo.size.height

            cursorShape
                .scaleEffect(interactionScale * cursorScale * cursorStyle.defaultScale * visibilityScale)
                .position(x: x, y: y)
                .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: interactionState)
                .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: highVisibilityMode)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var cursorShape: some View {
        switch cursorStyle {
        case .kamihiDot:
            kamihiCursor
        case .classicArrow:
            arrowCursor
        case .precisionCrosshair:
            crosshairCursor
        case .largeAccessibility:
            largeAccessibilityCursor
        }
    }

    @ViewBuilder
    private var kamihiCursor: some View {
        switch interactionState {
        case .textEditing:
            Image(systemName: "textformat")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(highVisibilityMode ? 0.90 : 0.72), in: Capsule())
                .overlay {
                    if highVisibilityMode {
                        Capsule().strokeBorder(.white, lineWidth: 1.4)
                    }
                }

        case .resizing(let edge):
            Image(systemName: resizeSymbol(for: edge))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(.black.opacity(highVisibilityMode ? 0.92 : 0.72), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(highVisibilityMode ? 1.0 : 0.45), lineWidth: highVisibilityMode ? 1.5 : 0.8))

        case .dragging:
            ZStack {
                Circle()
                    .fill(.black.opacity(highVisibilityMode ? 0.92 : 0.72))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(.white.opacity(highVisibilityMode ? 1.0 : 0.40), lineWidth: highVisibilityMode ? 1.5 : 0.8))
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
            }

        case .busy:
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
                .frame(width: 24, height: 24)
                .background(.black.opacity(highVisibilityMode ? 0.92 : 0.72), in: Circle())
                .overlay {
                    if highVisibilityMode {
                        Circle().strokeBorder(.white, lineWidth: 1.5)
                    }
                }

        case .defaultState, .hoveringLink, .clicking:
            ZStack {
                Circle()
                    .fill(.black.opacity(highVisibilityMode ? 0.90 : 0.70))
                    .frame(width: effectiveDotDiameter, height: effectiveDotDiameter)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                .white.opacity(highVisibilityMode ? 1.0 : (interactionState == .hoveringLink ? 0.72 : 0.44)),
                                lineWidth: highVisibilityMode ? 1.6 : 0.8
                            )
                    )
                    .shadow(color: .black.opacity(highVisibilityMode ? 0.52 : 0.34), radius: highVisibilityMode ? 4 : 3, x: 0, y: 1)

                Circle()
                    .fill(.white)
                    .frame(width: highVisibilityMode ? 5.5 : 4.5, height: highVisibilityMode ? 5.5 : 4.5)
            }
        }
    }

    /// Two-layer SF Symbol rendering keeps the arrow visible on both very light
    /// webpages and dark media without relying on an expensive animated effect.
    private var arrowCursor: some View {
        ZStack {
            Image(systemName: "cursorarrow")
                .font(.system(size: highVisibilityMode ? 23 : 21, weight: .heavy))
                .foregroundStyle(.black.opacity(highVisibilityMode ? 1.0 : 0.92))
            Image(systemName: "cursorarrow")
                .font(.system(size: highVisibilityMode ? 19 : 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(highVisibilityMode ? 0.58 : 0.38), radius: highVisibilityMode ? 3 : 2, x: 0, y: 1)
        .offset(x: 6, y: 6)
    }

    /// Precision mode needs a stable center mark even over white documents.
    /// Draw a dark backing cross first, then the thin light cross on top.
    private var crosshairCursor: some View {
        ZStack {
            Circle()
                .strokeBorder(.black.opacity(highVisibilityMode ? 1.0 : 0.86), lineWidth: highVisibilityMode ? 4 : 3)
                .frame(width: 20, height: 20)
            Rectangle()
                .fill(.black.opacity(highVisibilityMode ? 1.0 : 0.88))
                .frame(width: highVisibilityMode ? 4 : 3, height: 26)
            Rectangle()
                .fill(.black.opacity(highVisibilityMode ? 1.0 : 0.88))
                .frame(width: 26, height: highVisibilityMode ? 4 : 3)

            Circle()
                .strokeBorder(.white.opacity(0.96), lineWidth: highVisibilityMode ? 1.4 : 1)
                .frame(width: 18, height: 18)
            Rectangle()
                .fill(.white)
                .frame(width: highVisibilityMode ? 1.5 : 1, height: 24)
            Rectangle()
                .fill(.white)
                .frame(width: 24, height: highVisibilityMode ? 1.5 : 1)
        }
    }

    /// The accessibility cursor uses a true contrasting silhouette instead of
    /// only a shadow, so its edge remains readable across mixed desktop content.
    private var largeAccessibilityCursor: some View {
        ZStack {
            Image(systemName: "cursorarrow")
                .font(.system(size: highVisibilityMode ? 37 : 33, weight: .heavy))
                .foregroundStyle(.black.opacity(highVisibilityMode ? 1.0 : 0.94))
            Image(systemName: "cursorarrow")
                .font(.system(size: highVisibilityMode ? 32 : 29, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(highVisibilityMode ? 0.64 : 0.46), radius: highVisibilityMode ? 3.5 : 2.5, x: 0, y: 1)
        .offset(x: 10, y: 10)
    }

    /// Respect the user's iOS accessibility visibility preferences on the
    /// external desktop too. Increase Contrast and Differentiate Without Color
    /// both strengthen the cursor silhouette without depending on a hue change.
    private var highVisibilityMode: Bool {
        colorSchemeContrast == .increased || differentiateWithoutColor
    }

    private var visibilityScale: CGFloat {
        guard highVisibilityMode, cursorStyle != .largeAccessibility else { return 1.0 }
        return 1.12
    }

    private var effectiveDotDiameter: CGFloat {
        dotDiameter + (highVisibilityMode ? 3 : 0)
    }

    private var dotDiameter: CGFloat {
        switch interactionState {
        case .hoveringLink: return 22
        case .clicking: return 14
        default: return 18
        }
    }

    private var interactionScale: CGFloat {
        switch interactionState {
        case .defaultState: return 1.0
        case .hoveringLink: return 1.02
        case .clicking: return 0.92
        case .dragging: return 1.0
        case .textEditing: return 1.0
        case .resizing: return 1.0
        case .busy: return 1.0
        }
    }

    private func resizeSymbol(for edge: String) -> String {
        switch edge {
        case "left", "right":
            return "arrow.left.and.right"
        case "top", "bottom":
            return "arrow.up.and.down"
        case "topLeft", "bottomRight":
            return "arrow.up.left.and.arrow.down.right"
        case "topRight", "bottomLeft":
            return "arrow.up.right.and.arrow.down.left"
        default:
            return "arrow.up.left.and.arrow.down.right"
        }
    }
}
