import SwiftUI

/// Desktop-first launch experience. Startup choices are layouts, not separate products.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @State private var selectedProfile = DesktopLaunchProfile.selected
    @State private var showSetup = false

    private let columns = [
        GridItem(.flexible(), spacing: KamihiTheme.Spacing.sm),
        GridItem(.flexible(), spacing: KamihiTheme.Spacing.sm)
    ]

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            ScrollView {
                VStack(spacing: KamihiTheme.Spacing.lg) {
                    headerSection
                    featuredDesktopCard

                    Button {
                        DesktopSetupProgress().beginReview()
                        showSetup = true
                    } label: {
                        Label("Connection & setup guide", systemImage: "sparkles.tv")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 560)

                    VStack(alignment: .leading, spacing: KamihiTheme.Spacing.sm) {
                        Text("Choose how to start")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("This only chooses the starting layout. Once Kamihi Desktop opens, you can launch any app, resize windows, change workspace, and use it like your own iOS desktop.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: columns, spacing: KamihiTheme.Spacing.sm) {
                            ForEach(DesktopLaunchProfile.allCases) { profile in
                                profileCard(profile)
                            }
                        }
                    }
                    .frame(maxWidth: 560)

                    #if DEBUG
                    Button {
                        DesktopLaunchProfile.selected = selectedProfile
                        router.startDesktopLab()
                    } label: {
                        Label("Open Desktop Lab", systemImage: "flask.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 560)
                    #endif
                }
                .padding(.horizontal, KamihiTheme.Spacing.lg)
                .padding(.vertical, KamihiTheme.Spacing.xl)
            }
        }
        .sheet(isPresented: $showSetup) {
            DesktopSetupView(
                onFinish: {
                    showSetup = false
                    selectedProfile = DesktopLaunchProfile.selected
                    if ExternalDisplayCoordinator.shared.isConnected {
                        selectedProfile.apply(to: DesktopSession.shared)
                    }
                    router.selectMode(.externalDesktop)
                },
                onLater: { showSetup = false }
            )
        }
    }

    private var headerSection: some View {
        VStack(spacing: KamihiTheme.Spacing.xs) {
            Text("KAMIHI DESKTOP")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(.tint)

            Text("Your iPhone desktop")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Connect RayNeo or another external display and use the iPhone as the trackpad, keyboard, launcher, and secure touch surface.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
    }

    private var featuredDesktopCard: some View {
        HStack(spacing: KamihiTheme.Spacing.md) {
            Image(systemName: "display.2")
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("One desktop. Use it however you want.")
                    .font(.headline)
                Text("Browse, watch, write and organize your files in a layout that suits you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(KamihiTheme.Spacing.md)
        .frame(maxWidth: 560)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))
    }

    private func profileCard(_ profile: DesktopLaunchProfile) -> some View {
        let isSelected = selectedProfile == profile

        return Button {
            selectedProfile = profile
            DesktopLaunchProfile.selected = profile
            router.selectMode(.externalDesktop)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: profile.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Text(profile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.title)
        .accessibilityHint(profile.subtitle)
    }
}
