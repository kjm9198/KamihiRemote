import SwiftUI
import PhotosUI

/// macOS-style Wallpaper Chooser modal / sheet.
public struct DesktopWallpaperPickerView: View {
    @ObservedObject var manager = DesktopWallpaperManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    public init() {}

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)
    ]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Custom Photo Section
                    HStack {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Upload Custom Photo…")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)

                        if manager.customWallpaperImage != nil {
                            Button {
                                manager.selectWallpaper(id: "custom")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: manager.selectedWallpaperID == "custom" ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(manager.selectedWallpaperID == "custom" ? Color.green : Color.secondary)
                                    Text("Use Custom")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DockGeometryPreferenceKey.self,
                                        value: [DockItemGeometryPreference(
                                            target: .wallpaperOption(id: "custom"),
                                            frameInSurface: geo.frame(in: .named("desktopSurface"))
                                        )]
                                    )
                                }
                            )

                            Button {
                                manager.removeCustomWallpaper()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove custom wallpaper")
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

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
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DockGeometryPreferenceKey.self,
                                        value: [DockItemGeometryPreference(
                                            target: .wallpaperOption(id: wp.id),
                                            frameInSurface: geo.frame(in: .named("desktopSurface"))
                                        )]
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Wallpaper Chooser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(maxWidth: 580, maxHeight: 460)
        .background(.ultraThinMaterial)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    manager.setCustomWallpaper(image: image)
                }
            }
        }
    }
}
