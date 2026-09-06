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

    public static func action(at point: CGPoint, in frame: CGRect) -> Action? {
        let titleHeight = titleBarHeight(for: frame)
        guard point.y >= frame.minY,
              point.y <= frame.minY + titleHeight else { return nil }

        let verticalInset = min(titleHeight * 0.08, 0.003)
        let yRange = (frame.minY + verticalInset)...(frame.minY + titleHeight - verticalInset)
        guard yRange.contains(point.y) else { return nil }

        // Generous, non-overlapping left-side action zones. Anything to the right
        // of the green control falls through to the normal title-bar drag path.
        //   - Close:              [minX, minX + 0.036)
        //   - Minimize:           [minX + 0.036, minX + 0.070)
        //   - Full-screen/restore:[minX + 0.070, minX + 0.105]
        let closeMaxX = frame.minX + 0.036
        let minimizeMaxX = frame.minX + 0.070
        let maximizeMaxX = frame.minX + 0.105

        guard point.x >= frame.minX, point.x <= maximizeMaxX else { return nil }
        if point.x < closeMaxX { return .close }
        if point.x < minimizeMaxX { return .minimize }
        return .maximizeRestore
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
