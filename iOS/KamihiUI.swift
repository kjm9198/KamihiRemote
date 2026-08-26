import SwiftUI

enum KamihiUI {
    static let controlHeight: CGFloat = 44
    static let radiusLarge: CGFloat = 22
    static let radiusMedium: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let pad: CGFloat = 12
    static let gap: CGFloat = 10
    static let labelTracking: CGFloat = 1.6

    // Use semantic text styles so shared UI typography participates in Dynamic Type
    // instead of remaining locked to fixed point sizes.
    static var titleFont: Font { .system(.subheadline, design: .rounded, weight: .semibold) }
    static var bodyFont: Font { .system(.body, design: .rounded, weight: .semibold) }
    static var captionFont: Font { .system(.caption, design: .rounded, weight: .medium) }
}
