import SwiftUI
import Photos

/// Renders the complete desktop environment on the external display (or simulated in Desktop Lab).
struct ExternalDesktopCanvasView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @State private var showLauncher = false
    @State private var showDisplayCalibrationGuides = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { outer in
            let insets = display.safeInsets(for: outer.size)

            ZStack {
                // The canonical one-desktop experience starts from a genuinely
                // empty black canvas. Appearance settings continue to style app
                // surfaces/chrome, but never turn the desktop itself into a
                // decorative wallpaper.
                Color.black
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
        .onAppear {
            presentDisplayCalibrationGuides()
        }
        .onChange(of: display.metricsRevision) { _, _ in
            presentDisplayCalibrationGuides()
        }
    }

    private var desktopSurface: some View {
        ZStack {
            if let target = desktop.snapPreviewTarget {
                snapPreview(for: target)
                    .transition(.opacity)
                    .zIndex(1)
            }

            ForEach(desktop.windows) { window in
                DesktopWindowView(
                    window: window,
                    isActive: desktop.activeWindowID == window.id
                ) {
                    windowContent(for: window.title)
                }
                .zIndex(desktop.activeWindowID == window.id ? 4 : 2)
            }

            VStack {
                Spacer()
                DesktopDockView(onOpenLauncher: { showLauncher.toggle() })
                    .padding(.bottom, 12)
            }
            .zIndex(6)

            DesktopCursorView(
                cursorPosition: desktop.cursor,
                cursorStyle: settings.cursorStyle,
                interactionState: desktop.cursorInteractionState
            )
            .zIndex(20)
        }
        .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: desktop.snapPreviewTarget)
        .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: showLauncher)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Rectangle())
        .overlay {
            if showLauncher {
                (colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.18))
                    .onTapGesture { showLauncher = false }

                DesktopAppLauncherView()
                    .environmentObject(desktop)
                    .frame(maxWidth: 600, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))
                    .shadow(
                        color: .black.opacity(shouldSuppressDecorativeMotion ? 0 : (colorScheme == .dark ? 0.35 : 0.18)),
                        radius: shouldSuppressDecorativeMotion ? 0 : 24,
                        y: shouldSuppressDecorativeMotion ? 0 : 12
                    )
            }
        }
        .overlay {
            if display.horizontalSafeMargin > 0 || display.verticalSafeMargin > 0 {
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Show an explicit edge/corner test pattern briefly whenever the desktop canvas
    /// appears or iOS reports new display metrics. Persisted safe margins keep the
    /// guide visible so a user can tune overscan while watching the external display.
    /// This never changes the negotiated resolution or refresh rate.
    private var shouldShowDisplayCalibrationGuides: Bool {
        showDisplayCalibrationGuides
            || display.horizontalSafeMargin > 0
            || display.verticalSafeMargin > 0
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

    /// Treat system Low Power Mode and serious/critical thermal pressure like
    /// Reduce Motion for purely decorative desktop effects. Pointer movement,
    /// window manipulation and WebKit remain responsive; only non-essential
    /// transition/shadow work is suppressed until the system constraint clears.
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
        case "Notes":
            DesktopNotesView()
        case "Files":
            DesktopFilesView()
        case "Photos":
            DesktopPhotosView()
        default:
            VStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KamihiTheme.Colors.surfaceBackground)
        }
    }
}

/// PhotoKit-backed viewer for Kamihi Desktop. Opening Photos is the explicit user
/// action that can trigger iOS' standard permission sheet on the iPhone. Kamihi
/// reads only the assets iOS grants (including Limited Library selections) and does
/// not copy, persist, log, or upload the user's photo library.
private struct DesktopPhotosView: View {
    @StateObject private var model = DesktopPhotosModel()

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 190), spacing: 8)
    ]

    var body: some View {
        Group {
            switch model.authorizationStatus {
            case .authorized, .limited:
                if model.assets.isEmpty {
                    photosState(
                        symbol: "photo.on.rectangle.angled",
                        title: "No photos available",
                        detail: model.authorizationStatus == .limited
                            ? "iOS is sharing a limited selection with Kamihi."
                            : "Your photo library does not currently contain images."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(model.assets, id: \.localIdentifier) { asset in
                                DesktopPhotoThumbnail(asset: asset)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(10)
                    }
                    .overlay(alignment: .topTrailing) {
                        if model.authorizationStatus == .limited {
                            Label("Limited Photos", systemImage: "checkmark.shield.fill")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                                .accessibilityLabel("Limited Photos access")
                        }
                    }
                }
            case .denied, .restricted:
                photosState(
                    symbol: "photo.badge.exclamationmark",
                    title: "Photos access is off",
                    detail: "Kamihi cannot read the photo library. Change Photos access for Kamihi in iPhone Settings to use this window."
                )
            case .notDetermined:
                photosState(
                    symbol: "photo.stack",
                    title: "Choose Photos access on iPhone",
                    detail: "iOS will ask whether Kamihi may show your photos on the connected desktop. Limited access is supported."
                )
            @unknown default:
                photosState(
                    symbol: "photo.stack",
                    title: "Photos unavailable",
                    detail: "iOS returned an unknown Photos permission state."
                )
            }
        }
        .background(KamihiTheme.Colors.surfaceBackground)
        .task {
            await model.start()
        }
    }

    private func photosState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 430)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private final class DesktopPhotosModel: ObservableObject {
    @Published private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var assets: [PHAsset] = []

    func start() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = current

        if current == .notDetermined {
            // This request follows an explicit Photos launch from Kamihi's App
            // Library. The system owns the permission UI and credential/privacy
            // boundary; Kamihi never attempts to bypass or simulate it.
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        reloadGrantedAssets()
    }

    private func reloadGrantedAssets() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            assets = []
            return
        }

        let options = PHFetchOptions()
        options.fetchLimit = 60
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var nextAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            nextAssets.append(asset)
        }
        assets = nextAssets
    }
}

private struct DesktopPhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.055))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
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
            DispatchQueue.main.async {
                image = result
            }
        }
    }
}

/// High-contrast pattern for checking whether iOS-negotiated external output is
/// fully visible through the glasses. It is intentionally geometry-only: no mode
/// switching, refresh forcing, or RayNeo-private API assumptions.
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
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color.white.opacity(0.96), lineWidth: 2)
                    }

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
                    Text("DISPLAY CHECK")
                        .font(.caption.weight(.bold))
                    Text(capabilitySummary)
                        .font(.caption2.monospacedDigit())
                    Text(calibrationSummary)
                        .font(.caption2)
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
