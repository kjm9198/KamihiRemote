import SwiftUI

/// macOS-style Wallpaper Chooser modal / sheet.
public struct DesktopWallpaperPickerView: View {
    @ObservedObject var manager = DesktopWallpaperManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)
    ]

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(manager.wallpapers) { wp in
                        Button {
                            manager.selectWallpaper(id: wp.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    // Wallpaper Mini Preview
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(wp.backgroundColor)
                                        .frame(height: 100)
                                        .overlay {
                                            ZStack {
                                                RadialGradient(
                                                    colors: [wp.primaryColor.opacity(0.8), Color.clear],
                                                    center: .topTrailing,
                                                    startRadius: 10,
                                                    endRadius: 90
                                                )
                                                RadialGradient(
                                                    colors: [wp.accentColor.opacity(0.7), wp.secondaryColor.opacity(0.4), Color.clear],
                                                    center: .bottomLeading,
                                                    startRadius: 10,
                                                    endRadius: 80
                                                )
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(
                                                    manager.selectedWallpaperID == wp.id ? Color.cyan : Color.white.opacity(0.2),
                                                    lineWidth: manager.selectedWallpaperID == wp.id ? 2.5 : 0.8
                                                )
                                        }

                                    if manager.selectedWallpaperID == wp.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color.white, Color.blue)
                                            .padding(6)
                                    }
                                }

                                Text(wp.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)

                                Text(wp.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .navigationTitle("Wallpaper Chooser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(maxWidth: 580, maxHeight: 420)
        .background(.ultraThinMaterial)
    }
}
