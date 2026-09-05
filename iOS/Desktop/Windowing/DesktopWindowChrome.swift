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

        // The rendered buttons are visually compact, but the software pointer on
        // glasses needs desktop-grade forgiveness. Treat the trailing controls as
        // one continuous interaction cluster and partition it into three adjacent
        // actions. That removes dead strips between X / maximize / minimize while
        // keeping ownership deterministic: every point inside the cluster resolves
        // to exactly one action and never leaks through into title-bar dragging.
        let visualExtent = min(max(frame.width * 0.066, 0.020), 0.030)
        let targetExtent = max(visualExtent, 0.028)
        let visualGap = max(min(frame.width * 0.010, 0.006), 0.003)
        let trailing = min(max(frame.width * 0.016, 0.006), 0.012)

        let hitHeight = min(max(titleHeight * 0.92, 0.034), titleHeight)
        let yCenter = frame.minY + titleHeight / 2
        let yRange = (yCenter - hitHeight / 2)...(yCenter + hitHeight / 2)
        guard yRange.contains(point.y) else { return nil }

        // Preserve approximately the existing visual spacing, but include the
        // inter-button gaps in the tappable cluster. The region boundaries sit at
        // the midpoint of each visual gap, so aiming between icons still selects
        // the nearest intended control instead of doing nothing or starting drag.
        let closeCenterX = frame.maxX - trailing - targetExtent / 2
        let maximizeCenterX = closeCenterX - targetExtent - visualGap
        let minimizeCenterX = maximizeCenterX - targetExtent - visualGap

        let closeMaxX = min(frame.maxX, closeCenterX + targetExtent / 2 + visualGap / 2)
        let closeMinX = (closeCenterX + maximizeCenterX) / 2
        let maximizeMaxX = closeMinX
        let maximizeMinX = (maximizeCenterX + minimizeCenterX) / 2
        let minimizeMaxX = maximizeMinX
        let minimizeMinX = max(frame.minX, minimizeCenterX - targetExtent / 2 - visualGap / 2)

        guard point.x >= minimizeMinX, point.x <= closeMaxX else { return nil }
        if point.x >= closeMinX { return .close }
        if point.x >= maximizeMinX && point.x <= maximizeMaxX { return .maximizeRestore }
        if point.x >= minimizeMinX && point.x <= minimizeMaxX { return .minimize }
        return nil
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
