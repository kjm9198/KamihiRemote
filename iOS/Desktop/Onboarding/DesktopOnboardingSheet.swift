import SwiftUI
import UniformTypeIdentifiers

/// Fast first-run setup for Kamihi Desktop. It teaches only the interactions a
/// new user needs, confirms the connected-display path, and makes Safari import
/// optional instead of blocking the desktop behind setup screens.
public struct DesktopOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedDesktopOnboarding") private var hasCompletedDesktopOnboarding = false
    @ObservedObject private var display = ExternalDisplayCoordinator.shared
    @ObservedObject private var browser = DesktopBrowserState.shared
    @ObservedObject private var glass = DesktopGlassAppearance.shared

    @State private var page = 0
    @State private var showSafariImporter = false
    @State private var importMessage: String?

    private let pageCount = 4

    public init() {}

    public var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    gesturesPage.tag(1)
                    displayPage.tag(2)
                    finishPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
                    .padding(18)
            }
        }
        .fileImporter(
            isPresented: $showSafariImporter,
            allowedContentTypes: [.html, .propertyList, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(
            "Safari Bookmarks",
            isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )
        ) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "display.2")
                .font(.system(size: 19, weight: .bold))
                .frame(width: 38, height: 38)
                .desktopGlassSurface(cornerRadius: 12, elevated: false)

            VStack(alignment: .leading, spacing: 2) {
                Text("Kamihi Desktop")
                    .font(.headline)
                Text(pageSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.accentColor : Color.primary.opacity(0.16))
                        .frame(width: index == page ? 24 : 7, height: 7)
                        .animation(KamihiTheme.Animation.fast, value: page)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Skip") { complete() }
                .buttonStyle(.bordered)

            Spacer()

            if page > 0 {
                Button("Back") {
                    withAnimation(KamihiTheme.Animation.standard) { page -= 1 }
                }
                .buttonStyle(.bordered)
            }

            Button(page == pageCount - 1 ? "Start Desktop" : "Continue") {
                if page == pageCount - 1 {
                    complete()
                } else {
                    withAnimation(KamihiTheme.Animation.standard) { page += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var pageSubtitle: String {
        switch page {
        case 0: return "One desktop. Your iPhone is the controller."
        case 1: return "Learn the gestures that matter."
        case 2: return "Tune RayNeo or your external display."
        default: return "Bring your bookmarks and start."
        }
    }

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero(
                    symbol: "iphone.and.arrow.forward",
                    title: "Your iPhone becomes the trackpad",
                    detail: "The external display stays a clean desktop. Apps open there; the phone handles pointer, keyboard and private touch-only flows."
                )

                HStack(spacing: 12) {
                    compactFeature("display", "One desktop", "No mode maze. Reconnect and return to the same workspace.")
                    compactFeature("rectangle.on.rectangle", "Real windows", "Open, close, resize, snap and restore apps deliberately.")
                    compactFeature("hand.raised.fill", "Private by design", "Passwords, pickers and secure flows stay on the iPhone.")
                }
            }
            .padding(24)
        }
    }

    private var gesturesPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero(
                    symbol: "hand.draw.fill",
                    title: "Five gestures are enough",
                    detail: "Kamihi should feel predictable before it feels clever. Window movement never starts by accident."
                )

                VStack(spacing: 10) {
                    gestureRow("1", "Move", "One finger moves the pointer.", "cursorarrow.motionlines")
                    gestureRow("2", "Click", "Tap to click. Double-click only where desktop behavior expects it.", "hand.tap.fill")
                    gestureRow("3", "Move a window", "Hold its title bar, then drag. Release to drop or snap.", "rectangle.and.hand.point.up.left.fill")
                    gestureRow("4", "Scroll", "Two fingers scroll naturally with momentum.", "arrow.up.and.down.and.arrow.left.and.right")
                    gestureRow("5", "Switch", "Three-finger swipe up opens Window Overview; left/right cycles windows.", "rectangle.stack.fill")
                }
                .padding(16)
                .desktopGlassSurface(cornerRadius: 22)
            }
            .padding(24)
        }
    }

    private var displayPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero(
                    symbol: display.isConnected ? "display.2" : "cable.connector",
                    title: display.isConnected ? "Display detected" : "You can finish without the glasses connected",
                    detail: display.isConnected ? display.negotiatedModeSummary : "Connect RayNeo later; Settings will show the negotiated resolution, refresh ceiling and calibration controls."
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Refresh preference").font(.headline)
                            Text(display.refreshNegotiationSummary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(display.capabilitySummary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        choiceButton("60 Hz", selected: display.preferredRefreshRate == 60) {
                            display.preferredRefreshRate = 60
                        }
                        choiceButton("120 Hz", selected: display.preferredRefreshRate == 120) {
                            display.preferredRefreshRate = 120
                        }
                    }

                    if !display.availableDisplayModes.isEmpty {
                        Divider()
                        Text("Available output modes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(display.availableDisplayModes.prefix(5)) { option in
                            Button {
                                display.selectDisplayMode(option)
                                haptic()
                            } label: {
                                HStack {
                                    Text(option.title)
                                    Spacer()
                                    if option.isCurrent { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .desktopGlassSurface(cornerRadius: 22)

                Text("Kamihi requests your preferred experience, but iOS and the connected hardware decide which refresh rates and modes are actually available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private var finishPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero(
                    symbol: "safari.fill",
                    title: "Safari bookmarks are optional",
                    detail: "Import an exported Safari bookmark file now, or do it later from Desktop Settings. Existing duplicates are safely ignored."
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Browser library", systemImage: "bookmark.fill")
                            .font(.headline)
                        Spacer()
                        Text("\(browser.bookmarks.count) bookmarks")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showSafariImporter = true
                    } label: {
                        Label("Choose Safari bookmark export", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)

                    Label("HTML and Safari property-list exports are supported. A copied Files document is accepted even when iOS does not return a security-scope token.", systemImage: "checkmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Label("Bookmarks are sanitized before local persistence. Kamihi does not import Safari passwords, cookies or tokens.", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .desktopGlassSurface(cornerRadius: 22)

                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.tint)
                    Text("After setup, open **Settings** from the Dock or App Library to change appearance, glass depth, RayNeo output, trackpad behavior, workspaces and browser options.")
                        .font(.footnote)
                }
                .padding(15)
                .desktopGlassSurface(cornerRadius: 18, elevated: false)
            }
            .padding(24)
        }
    }

    private func hero(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 82, height: 82)
                .desktopGlassSurface(cornerRadius: 26)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
        .padding(.top, 12)
    }

    private func compactFeature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.tint)
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .desktopGlassSurface(cornerRadius: 18)
    }

    private func gestureRow(_ number: String, _ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 13) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: 48)
    }

    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic()
        } label: {
            HStack {
                Text(title).fontWeight(.semibold)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importMessage = "No bookmark file was selected."
                return
            }
            do {
                let count = try DesktopBrowserState.shared.importSafariBookmarks(from: url)
                importMessage = count == 0 ? "Your Safari bookmarks are already up to date." : "Imported \(count) Safari bookmark\(count == 1 ? "" : "s")."
                haptic()
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "Import cancelled: \(error.localizedDescription)"
        }
    }

    private func complete() {
        hasCompletedDesktopOnboarding = true
        haptic()
        dismiss()
    }

    private func haptic() {
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
    }
}
