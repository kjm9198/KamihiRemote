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

    var body: some View {
        GeometryReader { geo in
            let x = cursorPosition.x * geo.size.width
            let y = cursorPosition.y * geo.size.height

            cursorShape
                .scaleEffect(interactionScale * cursorScale * cursorStyle.defaultScale)
                .position(x: x, y: y)
                .animation(reduceMotion ? nil : KamihiTheme.Animation.fast, value: interactionState)
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
                .background(.black.opacity(0.72), in: Capsule())

        case .resizing(let edge):
            Image(systemName: resizeSymbol(for: edge))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(.black.opacity(0.72), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 0.8))

        case .dragging:
            ZStack {
                Circle()
                    .fill(.black.opacity(0.72))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(.white.opacity(0.40), lineWidth: 0.8))
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
            }

        case .busy:
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
                .frame(width: 24, height: 24)
                .background(.black.opacity(0.72), in: Circle())

        case .defaultState, .hoveringLink, .clicking:
            ZStack {
                Circle()
                    .fill(.black.opacity(0.70))
                    .frame(width: dotDiameter, height: dotDiameter)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(interactionState == .hoveringLink ? 0.72 : 0.44), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.34), radius: 3, x: 0, y: 1)

                Circle()
                    .fill(.white)
                    .frame(width: 4.5, height: 4.5)
            }
        }
    }

    private var arrowCursor: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.65), radius: 2.5, x: 0, y: 1)
            .offset(x: 6, y: 6)
    }

    private var crosshairCursor: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.8), lineWidth: 1)
                .frame(width: 18, height: 18)
            Rectangle()
                .fill(.white)
                .frame(width: 1, height: 24)
            Rectangle()
                .fill(.white)
                .frame(width: 24, height: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    private var largeAccessibilityCursor: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
            .offset(x: 10, y: 10)
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
