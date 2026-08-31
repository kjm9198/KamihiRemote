import SwiftUI

/// Centralized semantic design tokens for Kamihi Remote & Kamihi Desktop.
/// Provides consistent typography, spacing, corner radii, materials, colors, and spatial animations.
public enum KamihiTheme {
    /// Primary app surface. Kept as a root alias so feature views do not hardcode black/white backgrounds.
    public static let surface = Colors.surfaceBackground

    // MARK: - Spacing
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radii
    public enum Radius {
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 14
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 28
        public static let pill: CGFloat = 999
    }

    // MARK: - Animations
    public enum Animation {
        /// Fast interactive touch/press feedback (150ms)
        public static let fast = SwiftUI.Animation.spring(response: 0.15, dampingFraction: 0.85)
        /// Standard UI state changes (280ms)
        public static let standard = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.86)
        /// Spatial window movement, maximize, and minimize (350ms)
        public static let spatial = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.88)
        /// Subtle launcher and sheet transitions (300ms)
        public static let overlay = SwiftUI.Animation.spring(response: 0.30, dampingFraction: 0.84)
    }

    // MARK: - Semantic Colors
    public enum Colors {
        public static let primaryText = Color.primary
        public static let secondaryText = Color.secondary
        public static let tertiaryText = Color(uiColor: .tertiaryLabel)

        public static let accent = Color.accentColor
        public static let brandTeal = Color(red: 0.18, green: 0.72, blue: 0.82)
        public static let brandPurple = Color(red: 0.58, green: 0.38, blue: 0.94)

        public static let surfaceBackground = Color(uiColor: .systemBackground)
        public static let secondarySurface = Color(uiColor: .secondarySystemBackground)
        public static let tertiarySurface = Color(uiColor: .tertiarySystemBackground)
        public static let groupedBackground = Color(uiColor: .systemGroupedBackground)

        public static let separator = Color(uiColor: .separator)
        public static let subtleBorder = Color.primary.opacity(0.12)
        public static let glow = Color.accentColor.opacity(0.28)
    }

    // MARK: - Atmospheric Meshes & Wallpapers
    public struct AtmosphericBackground: View {
        public init() {}

        public var body: some View {
            ZStack {
                Color.black
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.55, 0.48], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.07),
                        Color(red: 0.07, green: 0.08, blue: 0.14),
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color(red: 0.06, green: 0.07, blue: 0.13),
                        Color(red: 0.16, green: 0.20, blue: 0.34),
                        Color(red: 0.08, green: 0.07, blue: 0.16),
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.05, green: 0.06, blue: 0.12),
                        Color(red: 0.03, green: 0.04, blue: 0.08)
                    ]
                )
                .blur(radius: 18)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
