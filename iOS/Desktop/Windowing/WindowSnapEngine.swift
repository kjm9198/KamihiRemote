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

        // `DesktopSession.movePointer` clamps Y to 0.006, so the 0.014 band is
        // still reachable without demanding pixel-perfect contact with y == 0.
        // Keep maximize in the center where users naturally throw a title bar to
        // the top. The wider 0.030 band then divides the top edge into five clear
        // spatial zones: 1/3, 2/3, center 1/3, 2/3, 1/3. The live snap preview
        // makes the selected geometry visible before release and moving away
        // cancels it, so this adds capability without another permanent control.
        if cursor.y < 0.014, cursor.x >= 0.44, cursor.x <= 0.56 {
            return .maximize
        }
        if cursor.y < 0.030 {
            if cursor.x < 0.20 { return .leftThird }
            if cursor.x < 0.44 { return .leftTwoThirds }
            if cursor.x <= 0.56 { return .centerThird }
            if cursor.x <= 0.80 { return .rightTwoThirds }
            return .rightThird
        }

        return nil
    }
}
