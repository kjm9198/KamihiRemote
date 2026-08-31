import SwiftUI

/// Renders the software cursor on the Kamihi Desktop with micro-animations.
struct DesktopCursorView: View {
    var cursorPosition: CGPoint
    var cursorStyle: CursorStyle = .kamihiDot
    var interactionState: CursorInteractionState = .defaultState
    var cursorScale: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let x = cursorPosition.x * geo.size.width
            let y = cursorPosition.y * geo.size.height

            cursorShape
                .scaleEffect(interactionScale * cursorScale * cursorStyle.defaultScale)
                .position(x: x, y: y)
                .animation(KamihiTheme.Animation.fast, value: interactionState)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var cursorShape: some View {
        switch cursorStyle {
        case .kamihiDot:
            dotCursor
        case .classicArrow:
            arrowCursor
        case .precisionCrosshair:
            crosshairCursor
        case .largeAccessibility:
            largeAccessibilityCursor
        }
    }

    private var dotCursor: some View {
        ZStack {
            // Subtle dynamic hover ring
            Circle()
                .stroke(Color.cyan.opacity(interactionState == .hoveringLink ? 0.9 : 0.45), lineWidth: 1.5)
                .frame(width: interactionState == .hoveringLink ? 26 : 18, height: interactionState == .hoveringLink ? 26 : 18)

            // Precision core dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
        }
    }

    private var arrowCursor: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.white)
            .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
            .offset(x: 6, y: 6)
    }

    private var crosshairCursor: some View {
        Image(systemName: "plus")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.cyan)
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
    }

    private var largeAccessibilityCursor: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(Color.yellow)
            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
            .offset(x: 10, y: 10)
    }

    private var interactionScale: CGFloat {
        switch interactionState {
        case .defaultState: return 1.0
        case .hoveringLink: return 1.15
        case .clicking: return 0.82
        case .dragging: return 1.1
        case .textEditing: return 0.95
        case .resizing: return 1.1
        case .busy: return 1.05
        }
    }
}
