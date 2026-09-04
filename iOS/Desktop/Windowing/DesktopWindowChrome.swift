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

        // The rendered buttons are visually small, but a software pointer on
        // glasses needs forgiving hit targets. Keep the three actions separate
        // while expanding each target to roughly 44pt-equivalent normalized
        // geometry at a 1080p/1920-wide desktop. This fixes the visible X
        // appearing clickable while the pointer misses its old tiny hit box.
        let visualExtent = min(max(frame.width * 0.066, 0.020), 0.030)
        let hitExtent = max(visualExtent, 0.026)
        let gap = max(min(frame.width * 0.010, 0.006), 0.003)
        let trailing = min(max(frame.width * 0.016, 0.006), 0.012)

        let hitHeight = min(max(titleHeight * 0.88, 0.032), titleHeight)
        let yCenter = frame.minY + titleHeight / 2
        let yRange = (yCenter - hitHeight / 2)...(yCenter + hitHeight / 2)
        guard yRange.contains(point.y) else { return nil }

        let closeMaxX = frame.maxX - trailing
        let closeMinX = closeMaxX - hitExtent
        let maximizeMaxX = closeMinX - gap
        let maximizeMinX = maximizeMaxX - hitExtent
        let minimizeMaxX = maximizeMinX - gap
        let minimizeMinX = minimizeMaxX - hitExtent

        if (closeMinX...closeMaxX).contains(point.x) { return .close }
        if (maximizeMinX...maximizeMaxX).contains(point.x) { return .maximizeRestore }
        if (minimizeMinX...minimizeMaxX).contains(point.x) { return .minimize }
        return nil
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
