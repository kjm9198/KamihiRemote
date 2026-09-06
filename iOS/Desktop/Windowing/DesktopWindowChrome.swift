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

        let verticalInset = min(titleHeight * 0.08, 0.003)
        let yRange = (frame.minY + verticalInset)...(frame.minY + titleHeight - verticalInset)
        guard yRange.contains(point.y) else { return nil }

        // The rendered buttons are placed along the trailing edge of the title bar.
        // Partition the trailing region into three generous, non-overlapping action zones
        // so that the iPhone software pointer can reliably activate them without misclassification:
        //   - Close: [frame.maxX - 0.036, frame.maxX]
        //   - Maximize/Restore: [frame.maxX - 0.070, frame.maxX - 0.036)
        //   - Minimize: [frame.maxX - 0.105, frame.maxX - 0.070)
        //   - Left of frame.maxX - 0.105 falls through cleanly into title-bar dragging.
        let closeMinX = frame.maxX - 0.036
        let maximizeMinX = frame.maxX - 0.070
        let minimizeMinX = frame.maxX - 0.105

        guard point.x >= minimizeMinX, point.x <= frame.maxX else { return nil }
        if point.x >= closeMinX { return .close }
        if point.x >= maximizeMinX { return .maximizeRestore }
        return .minimize
    }

    public static func contentTop(for frame: CGRect) -> CGFloat {
        frame.minY + titleBarHeight(for: frame)
    }
}
