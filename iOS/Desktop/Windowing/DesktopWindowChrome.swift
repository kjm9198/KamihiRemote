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

        // The rendered buttons are intentionally compact, but the iPhone-driven
        // software pointer needs a larger desktop-grade target. Keep one continuous
        // interaction cluster and partition it into three adjacent actions so there
        // are no dead strips that can accidentally fall through into title-bar drag.
        //
        // At a typical 1080p floating-window width this gives each action roughly a
        // 60–70 px horizontal target while preserving the visual spacing of the
        // compact controls. The geometry stays normalized and therefore scales with
        // the negotiated external-display canvas rather than assuming a pixel mode.
        let visualExtent = min(max(frame.width * 0.066, 0.020), 0.030)
        let targetExtent = max(visualExtent, 0.034)
        let visualGap = max(min(frame.width * 0.010, 0.006), 0.003)
        let trailing = min(max(frame.width * 0.016, 0.006), 0.012)

        // Use nearly the complete title-bar height. The pointer is already required
        // to be inside the title bar, so extra vertical forgiveness cannot collide
        // with web/native content below it, and it keeps close/maximize/minimize
        // reachable when glasses scaling or a large software pointer is enabled.
        let verticalInset = min(titleHeight * 0.08, 0.003)
        let yRange = (frame.minY + verticalInset)...(frame.minY + titleHeight - verticalInset)
        guard yRange.contains(point.y) else { return nil }

        // Preserve approximately the existing visual spacing, but include the
        // inter-button gaps in the tappable cluster. Region boundaries sit at the
        // midpoint of each visual gap, so aiming between icons selects the nearest
        // intended control instead of doing nothing or starting a window drag.
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
