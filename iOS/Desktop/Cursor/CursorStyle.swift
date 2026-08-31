import Foundation

/// Defines available pointer visual representations on Kamihi Desktop.
public enum CursorStyle: String, CaseIterable, Identifiable, Codable {
    case kamihiDot = "Kamihi Dot"
    case classicArrow = "Classic Arrow"
    case precisionCrosshair = "Precision"
    case largeAccessibility = "Large Accessibility"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .kamihiDot:
            return "Precision circular dot with adaptive dynamic hover ring."
        case .classicArrow:
            return "Familiar high-contrast pointer arrow."
        case .precisionCrosshair:
            return "Crosshair cursor for pixel-accurate manipulation."
        case .largeAccessibility:
            return "High-contrast enlarged pointer for enhanced readability."
        }
    }

    public var defaultScale: Double {
        switch self {
        case .kamihiDot: return 1.0
        case .classicArrow: return 1.0
        case .precisionCrosshair: return 1.1
        case .largeAccessibility: return 1.6
        }
    }
}
