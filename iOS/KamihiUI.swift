import SwiftUI

enum KamihiUI {
    // Keep shared navigation and utility controls comfortably above Apple's 44 pt
    // minimum touch target so they are easier to hit one-handed and with motor impairments.
    static let controlHeight: CGFloat = 48
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
