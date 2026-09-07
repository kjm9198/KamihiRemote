import SwiftUI
import Photos

/// Renders the complete persistent desktop environment on the external display or
/// in Desktop Lab. Every launcher route now resolves to a real app surface rather
/// than falling through to a placeholder window.
struct ExternalDesktopCanvasView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @State private var showLauncher = false
    @State private var showDisplayCalibrationGuides = false
    @State private var showWallpaperPicker = false
    @AppStorage("kamihi.desktop.showWidgets") private var showWidgets = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { outer in
            let insets = display.safeInsets(for: outer.size)

            ZStack {
                DesktopWallpaperView()
                    .ignoresSafeArea()

                desktopSurface
                    .padding(.top, insets.top)
                    .padding(.leading, insets.leading)
                    .padding(.bottom, insets.bottom)
                    .padding(.trailing, insets.trailing)

                if shouldShowDisplayCalibrationGuides {
                    DisplayCalibrationGuideView(
                        safeInsets: insets,
                        capabilitySummary: display.capabilitySummary,
                        calibrationSummary: display.calibrationSummary
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(100)
                }
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
        .onAppear { presentDisplayCalibrationGuides() }
        .onChange(of: display.metricsRevision) { _, _ in presentDisplayCalibrationGuides() }
    }

    private var desktopSurface: some View {
        GeometryReader { surfaceGeo in
            let surfaceSize = surfaceGeo.size

            ZStack {
                DesktopWallpaperView()

                if showWidgets {
                    HStack {
                        Spacer()
                        DesktopWidgetsView()
                    }
                    .zIndex(1)
                }

                if let target = desktop.snapPreviewTarget {
                    snapPreview(for: target)
                        .transition(.opacity)
                        .zIndex(2)
                }

                ForEach(desktop.windows) { window in
                    DesktopWindowView(window: window, isActive: desktop.activeWindowID == window.id) {
                        windowContent(for: window.title)
                    }
                    .zIndex(desktop.activeWindowID == window.id ? 4 : 3)
                }

                if let assist = desktop.splitAssistState {
                    DesktopSplitAssistOverlay(state: assist, surfaceSize: surfaceSize)
                        .zIndex(6)
                        .transition(.opacity)
                }

                VStack {
                    DesktopMenuBarView(
                        showWallpaperPicker: $showWallpaperPicker,
                        showWidgets: $showWidgets
                    )

                    Spacer()

                    DesktopDockView(
                        onOpenLauncher: { showLauncher.toggle() },
                        onOpenWallpaperPicker: {
                            showWallpaperPicker.toggle()
                            desktop.showWallpaperPicker = showWallpaperPicker
                        }
                    )
                    .padding(.bottom, 10)
                    .offset(y: (desktop.autohideDock && !desktop.isDockVisible) ? 85 : 0)
                    .animation(shouldSuppressDecorativeMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: desktop.isDockVisible)
                    .animation(shouldSuppressDecorativeMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: desktop.autohideDock)
                }
                .zIndex(10)
            }
            .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: desktop.snapPreviewTarget)
            .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: showLauncher)
            .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: showWallpaperPicker)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Rectangle())
            .overlay {
                if showLauncher {
                    (colorScheme == .dark ? Color.black.opacity(0.38) : Color.black.opacity(0.18))
                        .ignoresSafeArea()
                        .onTapGesture {
                            showLauncher = false
                            DesktopDockHitRegistry.shared.isLauncherOpen = false
                        }

                    DesktopAppLauncherView()
                        .environmentObject(desktop)
                        .frame(maxWidth: 860, maxHeight: 560)
                        .desktopGlassSurface(cornerRadius: 24)
                }

                if showWallpaperPicker {
                    (colorScheme == .dark ? Color.black.opacity(0.34) : Color.black.opacity(0.18))
                        .onTapGesture {
                            showWallpaperPicker = false
                            desktop.showWallpaperPicker = false
                        }

                    DesktopWallpaperPickerView()
                        .desktopGlassSurface(cornerRadius: KamihiTheme.Radius.lg)
                }

                if desktop.showNotifications {
                    ZStack(alignment: .topTrailing) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { desktop.showNotifications = false }

                        DesktopNotificationCenterView()
                            .padding(.top, 32)
                            .padding(.trailing, 16)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(20)
                }

                if desktop.showControlCenter {
                    ZStack(alignment: .topTrailing) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { desktop.showControlCenter = false }

                        DesktopControlCenterView()
                            .padding(.top, 32)
                            .padding(.trailing, 54)
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .coordinateSpace(name: "desktopSurface")
            .onPreferenceChange(DockGeometryPreferenceKey.self) { preferences in
                guard surfaceSize.width > 0, surfaceSize.height > 0 else { return }
                let entries = preferences.map { pref in
                    let frame = pref.frameInSurface
                    let normalized = CGRect(
                        x: frame.minX / surfaceSize.width,
                        y: frame.minY / surfaceSize.height,
                        width: frame.width / surfaceSize.width,
                        height: frame.height / surfaceSize.height
                    )
                    return DesktopDockHitRegistry.Entry(target: pref.target, normalizedFrame: normalized)
                }
                DesktopDockHitRegistry.shared.update(entries: entries)
            }
            .onAppear {
                DesktopDockHitRegistry.shared.onToggleLauncher = {
                    showLauncher.toggle()
                    DesktopDockHitRegistry.shared.isLauncherOpen = showLauncher
                }
                DesktopDockHitRegistry.shared.onDismissLauncher = {
                    showLauncher = false
                    DesktopDockHitRegistry.shared.isLauncherOpen = false
                }
                DesktopDockHitRegistry.shared.onToggleWallpaper = {
                    showWallpaperPicker.toggle()
                    desktop.showWallpaperPicker = showWallpaperPicker
                }
            }
            .onChange(of: showLauncher) { _, isOpen in
                DesktopDockHitRegistry.shared.isLauncherOpen = isOpen
            }
            .onChange(of: desktop.showWallpaperPicker) { _, isOpen in
                showWallpaperPicker = isOpen
            }
            .overlay {
                if display.hasCalibration {
                    Rectangle()
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                DesktopCursorView(
                    cursorPosition: desktop.cursor,
                    cursorStyle: settings.cursorStyle,
                    interactionState: desktop.cursorInteractionState
                )
                .allowsHitTesting(false)
                .zIndex(999)
            }
        }
    }

    private var shouldShowDisplayCalibrationGuides: Bool {
        showDisplayCalibrationGuides || display.hasCalibration
    }

    private func presentDisplayCalibrationGuides() {
        let revision = display.metricsRevision
        showDisplayCalibrationGuides = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard display.metricsRevision == revision else { return }
            showDisplayCalibrationGuides = false
        }
    }

    private var shouldSuppressDecorativeMotion: Bool {
        reduceMotion || power.lowPowerMode || power.thermalState == .serious || power.thermalState == .critical
    }

    private func snapPreview(for target: WindowSnapEngine.SnapTarget) -> some View {
        GeometryReader { geo in
            let normalized = WindowSnapEngine.frame(for: target)
            let frame = CGRect(
                x: normalized.minX * geo.size.width,
                y: normalized.minY * geo.size.height,
                width: normalized.width * geo.size.width,
                height: normalized.height * geo.size.height
            )

            RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.30), lineWidth: 1.5)
                )
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func windowContent(for title: String) -> some View {
        switch title {
        case "Browser":
            DesktopBrowserView()
        case "ChatGPT":
            DesktopChatGPTView()
        case "YouTube":
            DesktopYouTubeView()
        case "Documents":
            DesktopDocumentsView()
        case "Sheets":
            DesktopSheetsView()
        case "Notes":
            DesktopNotesView()
        case "Files":
            DesktopFilesView()
        case "Photos":
            DesktopPhotosView()
        case "Calculator":
            DesktopCalculatorView()
        case "Clipboard":
            DesktopClipboardCenterView().environmentObject(desktop)
        case "PDF Viewer":
            DesktopPreviewAppView()
        case "Settings":
            DesktopSettingsAppView().environmentObject(desktop)
        case "Display Diagnostics":
            DesktopDisplayDiagnosticsAppView()
        default:
            DesktopUnknownAppView(title: title)
        }
    }
}

/// Photos counterpart with a proper toolbar, library sidebar, asset inspector,
/// and complete photo deletion via PHPhotoLibrary.
private struct DesktopPhotosView: View {
    @ObservedObject private var store = DesktopPhotosStore.shared

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 170), spacing: 8)]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.purple)
                    Text("Photos")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 11)
                .frame(height: DesktopShellMetrics.toolbarHeight)
                .desktopAppToolbar()

                VStack(spacing: 4) {
                    photosSidebarRow("Library", icon: "photo.stack.fill", selected: store.selectedFilter == .library) {
                        store.selectedFilter = .library
                        store.select(assetID: nil)
                    }
                    photosSidebarRow("Favorites", icon: "heart.fill", selected: store.selectedFilter == .favorites) {
                        store.selectedFilter = .favorites
                        store.select(assetID: nil)
                    }
                    photosSidebarRow("Recent", icon: "clock.fill", selected: store.selectedFilter == .recent) {
                        store.selectedFilter = .recent
                        store.select(assetID: nil)
                    }
                }
                .padding(7)
                Spacer()

                Text(store.authorizationStatus == .limited ? "Limited Library" : "On My iPhone")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .frame(width: 174)
            .desktopSidebarSurface()

            VStack(spacing: 0) {
                if let selected = store.selectedAsset {
                    // Detail Inspector Toolbar
                    HStack(spacing: 12) {
                        Button {
                            store.select(assetID: nil)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Photos")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            store.toggleFavoriteSelectedAsset()
                        } label: {
                            Image(systemName: selected.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selected.isFavorite ? Color.pink : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.deleteSelectedAsset()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: DesktopShellMetrics.toolbarHeight)
                    .desktopAppToolbar()

                    DesktopPhotoDetailView(asset: selected)
                } else {
                    // Grid Toolbar
                    HStack(spacing: 8) {
                        Text(store.selectedFilter.rawValue)
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                        if store.authorizationStatus == .limited {
                            Label("Limited", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(store.assets.count) photos")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: DesktopShellMetrics.toolbarHeight)
                    .desktopAppToolbar()

                    photosContent
                }
            }
        }
        .background(DesktopShellPalette.canvas)
        .task { await store.start() }
    }

    private func photosSidebarRow(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(selected ? Color.purple : Color.secondary)
                    .frame(width: 19)
                Text(title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(selected ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var photosContent: some View {
        switch store.authorizationStatus {
        case .authorized, .limited:
            if store.assets.isEmpty {
                photosState(
                    symbol: "photo.on.rectangle.angled",
                    title: "No photos available",
                    detail: store.authorizationStatus == .limited
                        ? "iOS is sharing a limited selection with Kamihi."
                        : "Your photo library does not currently contain images."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.assets, id: \.localIdentifier) { asset in
                            DesktopPhotoThumbnail(
                                asset: asset,
                                isSelected: store.selectedAssetID == asset.localIdentifier
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture {
                                store.select(assetID: asset.localIdentifier)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        case .denied, .restricted:
            photosState(symbol: "photo.badge.exclamationmark", title: "Photos access is off", detail: "Change Photos access for Kamihi in iPhone Settings to use this window.")
        case .notDetermined:
            photosState(symbol: "photo.stack", title: "Choose Photos access on iPhone", detail: "iOS will ask whether Kamihi may show photos on the connected desktop. Limited access is supported.")
        @unknown default:
            photosState(symbol: "photo.stack", title: "Photos unavailable", detail: "iOS returned an unknown Photos permission state.")
        }
    }

    private func photosState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Preview counterpart. PDF/image/document preview itself is provided by the same
/// secure sandbox library as Files, so the launcher no longer opens a placeholder.
private struct DesktopPreviewAppView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundStyle(.red)
                Text("Preview")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Open a document from Files")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()
            DesktopFilesView()
        }
        .background(DesktopShellPalette.canvas)
    }
}

private struct DesktopDisplayDiagnosticsAppView: View {
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundStyle(.teal)
                Text("Display Diagnostics")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(display.isConnected ? "Connected" : "Desktop Lab")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()

            ScrollView {
                VStack(spacing: 12) {
                    diagnosticCard("Output", icon: "display", value: display.capabilitySummary)
                    diagnosticCard("Calibration", icon: "viewfinder", value: display.calibrationSummary)
                    diagnosticCard("Preferred refresh", icon: "speedometer", value: "\(display.preferredRefreshRate) Hz")
                    diagnosticCard("Battery", icon: "battery.75percent", value: power.batteryPercentageText)
                    diagnosticCard("Thermal", icon: "thermometer.medium", value: power.thermalText)
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Physical check", systemImage: "checklist")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Confirm all four corners are visible, the pointer reaches every edge, text is sharp, window controls respond, and reconnect restores the same desktop.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .desktopInsetPanel()
                }
                .padding(16)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .background(DesktopShellPalette.canvas)
    }

    private func diagnosticCard(_ title: String, icon: String, value: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 34, height: 34)
                .background(Color.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(value).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .desktopInsetPanel()
    }
}

private struct DesktopUnknownAppView: View {
    let title: String
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "app.dashed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text("This application is not available in this build.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesktopShellPalette.canvas)
    }
}

private struct DesktopPhotoDetailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadFullImage)
    }

    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1920, height: 1080),
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            guard let result else { return }
            DispatchQueue.main.async { image = result }
        }
    }
}

private struct DesktopPhotoThumbnail: View {
    let asset: PHAsset
    var isSelected: Bool = false
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.055))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2.5 : 0.5)
        }
        .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : Color.clear, radius: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo")
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 360, height: 360),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            guard let result else { return }
            DispatchQueue.main.async { image = result }
        }
    }
}

private struct DesktopSplitAssistOverlay: View {
    @EnvironmentObject private var desktop: DesktopSession
    let state: DesktopSession.SplitAssistState
    let surfaceSize: CGSize

    var body: some View {
        let normalizedFrame = WindowSnapEngine.frame(for: state.target)
        let rect = CGRect(
            x: normalizedFrame.origin.x * surfaceSize.width,
            y: normalizedFrame.origin.y * surfaceSize.height,
            width: normalizedFrame.width * surfaceSize.width,
            height: normalizedFrame.height * surfaceSize.height
        )

        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.40), lineWidth: 1.5)
                }

            VStack(spacing: 14) {
                HStack {
                    Label("Split Screen Assist", systemImage: "rectangle.split.2x1.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        desktop.dismissSplitAssist()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("Select an open window to tile on the other half:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                ScrollView {
                    let candidates = desktop.windows.filter { state.eligibleWindowIDs.contains($0.id) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 14)], spacing: 14) {
                        ForEach(candidates) { candidate in
                            Button {
                                desktop.snapWindow(candidate.id, to: state.target)
                                desktop.dismissSplitAssist()
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                            .frame(height: 80)

                                        Image(systemName: appIcon(for: candidate.title))
                                            .font(.system(size: 30))
                                            .foregroundStyle(Color.accentColor)
                                    }

                                    Text(candidate.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
    }

    private func appIcon(for title: String) -> String {
        switch title {
        case "Browser": return "safari.fill"
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Documents": return "doc.text.fill"
        case "Sheets": return "tablecells.fill"
        case "Notes": return "note.text"
        case "Files": return "folder.fill"
        case "Photos": return "photo.on.rectangle.angled"
        case "Settings": return "gearshape.fill"
        case "Calculator": return "plus.forwardslash.minus"
        case "Clipboard": return "doc.on.clipboard.fill"
        default: return "app.fill"
        }
    }
}

private struct DisplayCalibrationGuideView: View {
    let safeInsets: EdgeInsets
    let capabilitySummary: String
    let calibrationSummary: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                calibrationGrid(in: geo.size)
                    .stroke(Color.white.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [7, 7]))
                Rectangle()
                    .strokeBorder(Color.black.opacity(0.75), lineWidth: 5)
                    .overlay { Rectangle().strokeBorder(Color.white.opacity(0.96), lineWidth: 2) }
                cornerMarks(in: geo.size)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .square))
                    .shadow(color: .black.opacity(0.8), radius: 1)
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
                    .padding(.top, safeInsets.top)
                    .padding(.leading, safeInsets.leading)
                    .padding(.bottom, safeInsets.bottom)
                    .padding(.trailing, safeInsets.trailing)
                VStack(spacing: 4) {
                    Text("DISPLAY CHECK").font(.caption.weight(.bold))
                    Text(capabilitySummary).font(.caption2.monospacedDigit())
                    Text(calibrationSummary).font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.72), in: Capsule())
                .padding(.top, 14)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func calibrationGrid(in size: CGSize) -> Path {
        Path { path in
            for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
                let x = size.width * fraction
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }

    private func cornerMarks(in size: CGSize) -> Path {
        let length: CGFloat = min(42, min(size.width, size.height) * 0.08)
        let inset: CGFloat = 5
        return Path { path in
            let corners: [(CGPoint, CGFloat, CGFloat)] = [
                (CGPoint(x: inset, y: inset), 1, 1),
                (CGPoint(x: size.width - inset, y: inset), -1, 1),
                (CGPoint(x: inset, y: size.height - inset), 1, -1),
                (CGPoint(x: size.width - inset, y: size.height - inset), -1, -1)
            ]
            for (point, xDirection, yDirection) in corners {
                path.move(to: point)
                path.addLine(to: CGPoint(x: point.x + length * xDirection, y: point.y))
                path.move(to: point)
                path.addLine(to: CGPoint(x: point.x, y: point.y + length * yDirection))
            }
        }
    }
}

private struct DesktopNotificationCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Notifications")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                notificationCard(
                    icon: "sparkles",
                    color: .blue,
                    title: "Kamihi Desktop Ready",
                    detail: "External display active at 120Hz ProMotion with hardware acceleration."
                )
                notificationCard(
                    icon: "safari.fill",
                    color: .cyan,
                    title: "Safari Bookmarks Available",
                    detail: "Import complete. All web bookmarks and history are ready."
                )
                notificationCard(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    title: "Local Isolation Active",
                    detail: "Zero telemetry and strict sandboxing enforced across all native workspaces."
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.red)
                    Text("No upcoming meetings or calendar events")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(width: 330)
        .desktopGlassSurface(cornerRadius: 18, elevated: true)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 18, x: 0, y: 10)
    }

    private func notificationCard(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .desktopInsetPanel()
    }
}

private struct DesktopControlCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var power = DesktopPowerMonitor.shared
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @State private var soundVolume: Double = 0.75
    @State private var displayBrightness: Double = 0.90

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                controlTile(icon: "wifi", title: "Wi-Fi", subtitle: "Connected", active: true)
                controlTile(icon: "dot.radiowaves.left.and.right", title: "AirDrop", subtitle: "Contacts Only", active: true)
            }

            HStack(spacing: 10) {
                controlTile(icon: "speedometer", title: "Refresh Rate", subtitle: "\(display.preferredRefreshRate) Hz", active: true)
                controlTile(icon: "battery.100.bolt", title: "Battery", subtitle: power.batteryPercentageText, active: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Display")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $displayBrightness, in: 0.1...1.0)
                    .tint(.white)
            }
            .padding(10)
            .desktopInsetPanel()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Sound")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $soundVolume, in: 0.0...1.0)
                    .tint(.white)
            }
            .padding(10)
            .desktopInsetPanel()
        }
        .padding(14)
        .frame(width: 300)
        .desktopGlassSurface(cornerRadius: 18, elevated: true)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 18, x: 0, y: 10)
    }

    private func controlTile(icon: String, title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
                .background(active ? Color.blue : Color.primary.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .desktopInsetPanel()
    }
}
