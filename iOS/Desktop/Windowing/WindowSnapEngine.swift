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
        case leftTwoThirds = "Left Two Thirds"
        case centerThird = "Center Third"
        case rightTwoThirds = "Right Two Thirds"
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
        case .leftTwoThirds:
            return CGRect(x: 0.012, y: topY, width: 0.647, height: totalHeight)
        case .centerThird:
            return CGRect(x: 0.341, y: topY, width: 0.318, height: totalHeight)
        case .rightTwoThirds:
            return CGRect(x: 0.341, y: topY, width: 0.647, height: totalHeight)
        case .rightThird:
            return CGRect(x: 0.670, y: topY, width: 0.318, height: totalHeight)

        case .maximize:
            return CGRect(x: 0.012, y: topY, width: 0.976, height: totalHeight)
        case .center:
            return CGRect(x: 0.150, y: 0.120, width: 0.700, height: 0.680)
        }
    }

    /// Evaluates cursor position during a deliberate title-bar drag to detect
    /// edge snapping preview intent. The outer left/right edges keep the familiar
    /// half/quarter zones. The top edge exposes one-third, two-thirds, center-third,
    /// and maximize layouts so every readiness-gate snap geometry is reachable
    /// through the same reversible preview-and-release interaction.
    public static func evaluateSnapIntent(cursor: CGPoint) -> SnapTarget? {
        if cursor.x < 0.035 {
            if cursor.y < 0.25 { return .topLeftQuarter }
            if cursor.y > 0.70 { return .bottomLeftQuarter }
            return .leftHalf
        }
        if cursor.x > 0.965 {
            if cursor.y < 0.25 { return .topRightQuarter }
            if cursor.y > 0.70 { return .bottomRightQuarter }
            return .rightHalf
        }

        // Top edge: dragging a window to the top triggers full screen / maximize.
        // Also supports left/right thirds if explicitly targeting top corners.
        if cursor.y < 0.035 {
            if cursor.x < 0.18 { return .leftThird }
            if cursor.x > 0.82 { return .rightThird }
            return .maximize
        }

        return nil
    }
}
