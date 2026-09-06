import SwiftUI
import UniformTypeIdentifiers

/// First-time onboarding experience for Kamihi Desktop.
/// Guides users through gestures, 120Hz ProMotion vs 60Hz and display resolutions,
/// and provides a clean Safari bookmarks import with Apple sandbox safety guarantees.
public struct DesktopOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedDesktopOnboarding") private var hasCompletedDesktopOnboarding = false
    @ObservedObject private var coordinator = ExternalDisplayCoordinator.shared
    @State private var selectedTab = 0
    @State private var showSafariFileImporter = false
    @State private var importResultMessage: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                gestureTutorialView
                    .tag(0)

                displayQualityView
                    .tag(1)

                safariImportView
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle(navigationTitleForTab(selectedTab))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if selectedTab < 2 {
                        Button("Next") {
                            withAnimation {
                                selectedTab += 1
                            }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .fontWeight(.bold)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showSafariFileImporter,
            allowedContentTypes: [.html, .propertyList, .data]
        ) { result in
            handleSafariFileImport(result: result)
        }
        .alert(
            "Safari Import",
            isPresented: Binding(
                get: { importResultMessage != nil },
                set: { if !$0 { importResultMessage = nil } }
            )
        ) {
            Button("OK") { importResultMessage = nil }
        } message: {
            if let importResultMessage {
                Text(importResultMessage)
            }
        }
    }

    private func navigationTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Desktop Gestures"
        case 1: return "Display Quality"
        case 2: return "Import & Privacy"
        default: return "Kamihi Desktop"
        }
    }

    private func completeOnboarding() {
        hasCompletedDesktopOnboarding = true
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
        dismiss()
    }

    // MARK: - Step 1: Gesture Tutorial

    private var gestureTutorialView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 12)

                    Text("Welcome to Kamihi Desktop")
                        .font(.title2.weight(.bold))

                    Text("Transform your iPhone into a precision glass trackpad and external desktop computer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    gestureCard(
                        icon: "cursorarrow.rays",
                        color: .blue,
                        title: "1-Finger Cursor Movement",
                        description: "Glide with one finger to move the desktop pointer with sub-pixel precision."
                    )

                    gestureCard(
                        icon: "hand.point.up.left.fill",
                        color: .indigo,
                        title: "Double-Tap to Open",
                        description: "Double-tap an app in Launchpad to open it, or double-tap text to select words."
                    )

                    gestureCard(
                        icon: "hand.tap.fill",
                        color: .purple,
                        title: "Hold Title Bar for 2 Seconds to Move",
                        description: "Hover over an app's top navbar and hold for ~2s to grab and move the window anywhere."
                    )

                    gestureCard(
                        icon: "rectangle.split.2x1.fill",
                        color: .teal,
                        title: "Edge Snapping",
                        description: "Drag a window to the left or right screen edge to snap 50%, or drag to the top to maximize."
                    )

                    gestureCard(
                        icon: "arrow.up.and.down.circle.fill",
                        color: .orange,
                        title: "2-Finger Inertial Scroll",
                        description: "Glide with two fingers for natural fluid scrolling on any webpage or document."
                    )

                    gestureCard(
                        icon: "contextualmenu.and.cursor",
                        color: .pink,
                        title: "2-Finger Tap Context Menu",
                        description: "Tap with two fingers to reveal context options like Copy, Paste, Look Up, and Share."
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func gestureCard(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    // MARK: - Step 2: Display Quality & Resolution

    private var displayQualityView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "display.2")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 12)

                    Text("Display Quality & Resolution")
                        .font(.title2.weight(.bold))

                    Text("Choose your preferred refresh rate and negotiated external display resolution.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                // 120Hz ProMotion vs 60Hz Standard
                VStack(alignment: .leading, spacing: 10) {
                    Text("REFRESH RATE MODE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    Button {
                        coordinator.preferredRefreshRate = 120
                        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                                .frame(width: 36, height: 36)
                                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("120 Hz ProMotion")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("RECOMMENDED")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.green, in: Capsule())
                                }

                                Text("Ultra-fluid motion, low input latency for AR glasses and 120Hz monitors.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if coordinator.preferredRefreshRate == 120 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(14)
                        .background(
                            coordinator.preferredRefreshRate == 120 ? Color.green.opacity(0.08) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    coordinator.preferredRefreshRate == 120 ? Color.green.opacity(0.40) : Color.primary.opacity(0.08),
                                    lineWidth: coordinator.preferredRefreshRate == 120 ? 1.5 : 0.8
                                )
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        coordinator.preferredRefreshRate = 60
                        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "battery.100")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("60 Hz Standard")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("Standard refresh rate suitable for legacy displays and battery preservation.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if coordinator.preferredRefreshRate == 60 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(14)
                        .background(
                            coordinator.preferredRefreshRate == 60 ? Color.blue.opacity(0.08) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    coordinator.preferredRefreshRate == 60 ? Color.blue.opacity(0.40) : Color.primary.opacity(0.08),
                                    lineWidth: coordinator.preferredRefreshRate == 60 ? 1.5 : 0.8
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Available Resolutions
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("DETECTED MONITOR RESOLUTIONS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !coordinator.isConnected {
                            Text("Plug into monitor to test")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    if coordinator.availableDisplayModes.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "cable.connector")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("1920×1080 (Default Target)")
                                    .font(.subheadline.weight(.semibold))
                                Text("Connect external monitor or RayNeo Air glasses to select hardware modes.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(coordinator.availableDisplayModes) { option in
                                Button {
                                    coordinator.selectDisplayMode(option)
                                    if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)

                                            if option.isCurrent {
                                                Text("Current Active Mode")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                            }
                                        }

                                        Spacer()

                                        if option.isCurrent {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        option.isCurrent ? Color.green.opacity(0.08) : Color.primary.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                option.isCurrent ? Color.green.opacity(0.35) : Color.primary.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Step 3: Safari Import & Privacy

    private var safariImportView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 12)

                    Text("Safari Bookmarks & Privacy")
                        .font(.title2.weight(.bold))

                    Text("Seamlessly bring your web bookmarks to Kamihi Desktop while keeping full privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                // Import Tutorial Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("HOW TO IMPORT FROM SAFARI")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        tutorialStep(
                            number: "1",
                            title: "Export Safari Bookmarks",
                            detail: "On Mac, open Safari and choose File > Export > Bookmarks... to save an HTML file to iCloud Drive. (Or on iPhone/iPad, save your exported bookmarks to Files)."
                        )

                        tutorialStep(
                            number: "2",
                            title: "Select the HTML File",
                            detail: "Tap the button below to pick the exported HTML file from the native iOS document picker."
                        )

                        tutorialStep(
                            number: "3",
                            title: "Instant Desktop Sync",
                            detail: "Bookmarks will instantly appear in Kamihi Browser's quick bar and App Library!"
                        )
                    }

                    Button {
                        showSafariFileImporter = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Import Safari Bookmarks File...")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(16)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                }
                .padding(.horizontal, 16)

                // Privacy & Safety Badges
                VStack(spacing: 10) {
                    safetyBadge(
                        icon: "lock.shield.fill",
                        color: .green,
                        title: "Strict iOS Sandbox Isolation",
                        detail: "Kamihi Desktop cannot access Safari's internal databases or files without your explicit document picker selection."
                    )

                    safetyBadge(
                        icon: "internaldrive.fill",
                        color: .teal,
                        title: "Zero Cloud Telemetry",
                        detail: "All imported bookmarks, browser data, and documents remain strictly local on your iPhone. Nothing is uploaded."
                    )

                    safetyBadge(
                        icon: "faceid",
                        color: .indigo,
                        title: "Passwords Stay in Keychain",
                        detail: "Kamihi never stores or logs passwords. Web logins use Apple's native iCloud Keychain and Face ID."
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func tutorialStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func safetyBadge(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func handleSafariFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importResultMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let count = try DesktopBrowserState.shared.importBookmarksHTML(data)
                importResultMessage = "Successfully imported \(count) bookmarks from Safari!"
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
            } catch {
                importResultMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importResultMessage = "Selection cancelled: \(error.localizedDescription)"
        }
    }
}
