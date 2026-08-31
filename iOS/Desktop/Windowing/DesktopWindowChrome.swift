import CoreGraphics

/// Shared geometry for visual window chrome and software-pointer hit testing.
/// External-display scenes are noninteractive, so close/minimize/maximize must
/// be routed through DesktopSession rather than relying on SwiftUI tap gestures.
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

        let extent = min(max(frame.width * 0.066, 0.020), 0.030)
        let gap = min(max(frame.width * 0.012, 0.004), 0.008)
        let trailing = min(max(frame.width * 0.018, 0.006), 0.012)
        let verticalPadding = max((titleHeight - extent) / 2, 0)
        let yRange = (frame.minY + verticalPadding)...(frame.minY + verticalPadding + extent)
        guard yRange.contains(point.y) else { return nil }

        let closeMaxX = frame.maxX - trailing
        let closeMinX = closeMaxX - extent
        let maximizeMaxX = closeMinX - gap
        let maximizeMinX = maximizeMaxX - extent
        let minimizeMaxX = maximizeMinX - gap
        let minimizeMinX = minimizeMaxX - extent

        if (closeMinX...closeMaxX).contains(point.x) { return .close }
        if (maximizeMinX...maximizeMaxX).contains(point.x) { return .maximizeRestore }
        if (minimizeMinX...minimizeMaxX).contains(point.x) { return .minimize }
        return nil
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
