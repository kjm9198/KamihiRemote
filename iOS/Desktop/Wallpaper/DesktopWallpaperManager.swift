import SwiftUI

/// Manages macOS-grade dynamic glass wallpapers and user wallpaper preferences.
@MainActor
public final class DesktopWallpaperManager: ObservableObject {
    public static let shared = DesktopWallpaperManager()

    public struct Wallpaper: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let subtitle: String
        public let primaryColor: Color
        public let secondaryColor: Color
        public let accentColor: Color
        public let backgroundColor: Color

        public init(
            id: String,
            name: String,
            subtitle: String,
            primaryColor: Color,
            secondaryColor: Color,
            accentColor: Color,
            backgroundColor: Color
        ) {
            self.id = id
            self.name = name
            self.subtitle = subtitle
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.accentColor = accentColor
            self.backgroundColor = backgroundColor
        }
    }

    public let wallpapers: [Wallpaper] = [
        Wallpaper(
            id: "sonoma-horizon",
            name: "Sonoma Horizon",
            subtitle: "macOS Sunset Glass",
            primaryColor: Color(red: 0.95, green: 0.40, blue: 0.35),
            secondaryColor: Color(red: 0.65, green: 0.20, blue: 0.70),
            accentColor: Color(red: 0.98, green: 0.72, blue: 0.30),
            backgroundColor: Color(red: 0.08, green: 0.05, blue: 0.18)
        ),
        Wallpaper(
            id: "sequoia-aurora",
            name: "Sequoia Aurora",
            subtitle: "macOS Emerald Glow",
            primaryColor: Color(red: 0.10, green: 0.65, blue: 0.55),
            secondaryColor: Color(red: 0.05, green: 0.35, blue: 0.50),
            accentColor: Color(red: 0.40, green: 0.85, blue: 0.60),
            backgroundColor: Color(red: 0.03, green: 0.10, blue: 0.14)
        ),
        Wallpaper(
            id: "ventura-solar",
            name: "Ventura Solar",
            subtitle: "macOS Radiant Amber",
            primaryColor: Color(red: 0.98, green: 0.55, blue: 0.15),
            secondaryColor: Color(red: 0.85, green: 0.25, blue: 0.20),
            accentColor: Color(red: 1.00, green: 0.80, blue: 0.35),
            backgroundColor: Color(red: 0.15, green: 0.06, blue: 0.04)
        ),
        Wallpaper(
            id: "monterey-dusk",
            name: "Monterey Dusk",
            subtitle: "macOS Indigo Violet",
            primaryColor: Color(red: 0.35, green: 0.25, blue: 0.85),
            secondaryColor: Color(red: 0.70, green: 0.15, blue: 0.60),
            accentColor: Color(red: 0.20, green: 0.60, blue: 0.95),
            backgroundColor: Color(red: 0.06, green: 0.04, blue: 0.16)
        ),
        Wallpaper(
            id: "cupertino-glass",
            name: "Cupertino Frosted",
            subtitle: "macOS Titanium Specular",
            primaryColor: Color(red: 0.45, green: 0.55, blue: 0.70),
            secondaryColor: Color(red: 0.30, green: 0.35, blue: 0.48),
            accentColor: Color(red: 0.75, green: 0.85, blue: 0.95),
            backgroundColor: Color(red: 0.09, green: 0.11, blue: 0.16)
        ),
        Wallpaper(
            id: "midnight-obsidian",
            name: "Midnight Nebula",
            subtitle: "macOS Deep Space",
            primaryColor: Color(red: 0.20, green: 0.15, blue: 0.38),
            secondaryColor: Color(red: 0.08, green: 0.22, blue: 0.35),
            accentColor: Color(red: 0.30, green: 0.50, blue: 0.80),
            backgroundColor: Color(red: 0.02, green: 0.02, blue: 0.05)
        )
    ]

    private let selectedKey = "kamihi.desktop.wallpaper.selected"
    private static let customWallpaperFileName = "kamihi_custom_wallpaper.jpg"

    @Published public var selectedWallpaperID: String {
        didSet {
            UserDefaults.standard.set(selectedWallpaperID, forKey: selectedKey)
        }
    }

    @Published public var customWallpaperImage: UIImage?

    public var currentWallpaper: Wallpaper {
        wallpapers.first(where: { $0.id == selectedWallpaperID }) ?? wallpapers[0]
    }

    public var isCustomWallpaperActive: Bool {
        selectedWallpaperID == "custom" && customWallpaperImage != nil
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: selectedKey)
        self.selectedWallpaperID = saved ?? "sonoma-horizon"
        self.customWallpaperImage = Self.loadCustomWallpaperFromDisk()
    }

    public func selectWallpaper(id: String) {
        if id == "custom" && customWallpaperImage != nil {
            selectedWallpaperID = "custom"
        } else if wallpapers.contains(where: { $0.id == id }) {
            selectedWallpaperID = id
        }
    }

    public func setCustomWallpaper(image: UIImage) {
        self.customWallpaperImage = image
        self.selectedWallpaperID = "custom"
        Self.saveCustomWallpaperToDisk(image)
    }

    public func removeCustomWallpaper() {
        self.customWallpaperImage = nil
        if selectedWallpaperID == "custom" {
            selectedWallpaperID = wallpapers[0].id
        }
        Self.deleteCustomWallpaperFromDisk()
    }

    private static var customWallpaperURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(customWallpaperFileName)
    }

    private static func loadCustomWallpaperFromDisk() -> UIImage? {
        guard let url = customWallpaperURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func saveCustomWallpaperToDisk(_ image: UIImage) {
        guard let url = customWallpaperURL,
              let data = image.jpegData(compressionQuality: 0.90) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func deleteCustomWallpaperFromDisk() {
        guard let url = customWallpaperURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Dynamic GPU-accelerated glass background for Kamihi Desktop.
public struct DesktopWallpaperView: View {
    @ObservedObject var manager = DesktopWallpaperManager.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        let wp = manager.currentWallpaper

        ZStack {
            if manager.isCustomWallpaperActive, let image = manager.customWallpaperImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Subtle darkened vignette to ensure desktop windows and text stay readable
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
            } else {
                wp.backgroundColor
                    .ignoresSafeArea()

                if !reduceTransparency {
                    // Layer 1: Ambient deep radial glow
                    RadialGradient(
                        colors: [
                            wp.primaryColor.opacity(0.45),
                            wp.secondaryColor.opacity(0.25),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 80,
                        endRadius: 900
                    )
                    .ignoresSafeArea()

                    // Layer 2: Radiant bottom-left aurora
                    RadialGradient(
                        colors: [
                            wp.accentColor.opacity(0.35),
                            wp.primaryColor.opacity(0.20),
                            Color.clear
                        ],
                        center: .bottomLeading,
                        startRadius: 50,
                        endRadius: 750
                    )
                    .ignoresSafeArea()

                    // Layer 3: Central glass refraction sweep
                    LinearGradient(
                        colors: [
                            wp.secondaryColor.opacity(0.30),
                            wp.primaryColor.opacity(0.20),
                            wp.accentColor.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    // Layer 4: Specular noise & frosted glass wash
                    Color.white.opacity(0.03)
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                }
            }
        }
    }
}
