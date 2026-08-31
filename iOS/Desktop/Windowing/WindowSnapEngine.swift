import CoreGraphics
import Foundation

/// Geometry calculation engine for multi-target window snapping.
public enum WindowSnapEngine {
    public enum SnapTarget: String, CaseIterable, Identifiable {
        case leftHalf = "Left Half"
        case rightHalf = "Right Half"
        case topLeftQuarter = "Top Left"
        case topRightQuarter = "Top Right"
        case bottomLeftQuarter = "Bottom Left"
        case bottomRightQuarter = "Bottom Right"
        case leftThird = "Left Third"
        case centerThird = "Center Third"
        case rightThird = "Right Third"
        case maximize = "Maximize"
        case center = "Center"

        public var id: String { rawValue }
    }

    /// Computes the normalized frame (0.0...1.0) in desktop coordinate space for a given target.
    public static func frame(for target: SnapTarget) -> CGRect {
        // Safe margins: top status bar (y: 0.045), bottom dock (height cutoff: 0.88)
        let topY: CGFloat = 0.045
        let totalHeight: CGFloat = 0.840

        switch target {
        case .leftHalf:
            return CGRect(x: 0.012, y: topY, width: 0.482, height: totalHeight)
        case .rightHalf:
            return CGRect(x: 0.506, y: topY, width: 0.482, height: totalHeight)

        case .topLeftQuarter:
            return CGRect(x: 0.012, y: topY, width: 0.482, height: totalHeight * 0.485)
        case .topRightQuarter:
            return CGRect(x: 0.506, y: topY, width: 0.482, height: totalHeight * 0.485)
        case .bottomLeftQuarter:
            return CGRect(x: 0.012, y: topY + totalHeight * 0.515, width: 0.482, height: totalHeight * 0.485)
        case .bottomRightQuarter:
            return CGRect(x: 0.506, y: topY + totalHeight * 0.515, width: 0.482, height: totalHeight * 0.485)

        case .leftThird:
            return CGRect(x: 0.012, y: topY, width: 0.318, height: totalHeight)
        case .centerThird:
            return CGRect(x: 0.341, y: topY, width: 0.318, height: totalHeight)
        case .rightThird:
            return CGRect(x: 0.670, y: topY, width: 0.318, height: totalHeight)

        case .maximize:
            return CGRect(x: 0.012, y: topY, width: 0.976, height: totalHeight)
        case .center:
            return CGRect(x: 0.150, y: 0.120, width: 0.700, height: 0.680)
        }
    }

    /// Evaluates cursor position during a drag to detect edge snapping preview intent.
    public static func evaluateSnapIntent(cursor: CGPoint) -> SnapTarget? {
        // Edge snapping thresholds
        if cursor.x < 0.025 {
            if cursor.y < 0.25 { return .topLeftQuarter }
            if cursor.y > 0.70 { return .bottomLeftQuarter }
            return .leftHalf
        }
        if cursor.x > 0.975 {
            if cursor.y < 0.25 { return .topRightQuarter }
            if cursor.y > 0.70 { return .bottomRightQuarter }
            return .rightHalf
        }
        if cursor.y < 0.025 {
            return .maximize
        }
        return nil
    }
}
