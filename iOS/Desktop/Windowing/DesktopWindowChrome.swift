import CoreGraphics

/// Shared geometry for visual window chrome and software-pointer hit testing.
/// External-display scenes are noninteractive, so close/minimize/full-screen must
/// be routed through DesktopSession rather than relying on SwiftUI tap gestures.
/// The hit zones intentionally mirror the macOS traffic-light order on the left:
/// red close, yellow minimize, green full-screen/restore.
public enum DesktopWindowChrome {
    public enum Action: String, Equatable {
        case minimize
        case maximizeRestore
        case close
    }

    public static func titleBarHeight(for frame: CGRect) -> CGFloat {
        min(max(frame.height * 0.095, 0.036), 0.052)
    }

    public static let trafficLightsWidth: CGFloat = 0.052
    public static let closeMaxXOffset: CGFloat = 0.018
    public static let minimizeMaxXOffset: CGFloat = 0.034
    public static let maximizeMaxXOffset: CGFloat = trafficLightsWidth

    public static func action(at point: CGPoint, in frame: CGRect) -> Action? {
        let titleHeight = titleBarHeight(for: frame)
        guard point.y >= frame.minY,
              point.y <= frame.minY + titleHeight else { return nil }

        let verticalInset = min(titleHeight * 0.08, 0.003)
        let yRange = (frame.minY + verticalInset)...(frame.minY + titleHeight - verticalInset)
        guard yRange.contains(point.y) else { return nil }

        // Generous, non-overlapping left-side action zones aligned with visual traffic lights.
        // On a 1920x1080 display:
        //   - Close:              [minX, minX + 0.018)  (~0 to ~34pt)
        //   - Minimize:           [minX + 0.018, minX + 0.034) (~34 to ~65pt)
        //   - Full-screen/restore:[minX + 0.034, minX + 0.052] (~65 to ~100pt)
        let closeMaxX = frame.minX + closeMaxXOffset
        let minimizeMaxX = frame.minX + minimizeMaxXOffset
        let maximizeMaxX = frame.minX + maximizeMaxXOffset

        guard point.x >= frame.minX, point.x <= maximizeMaxX else { return nil }
        if point.x < closeMaxX { return .close }
        if point.x < minimizeMaxX { return .minimize }
        return .maximizeRestore
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
