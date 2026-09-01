import SwiftUI

/// Desktop-first launch experience. Startup choices are layouts, not separate products.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selectedProfile = DesktopLaunchProfile.selected

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: KamihiTheme.Spacing.sm),
            GridItem(.flexible(), spacing: KamihiTheme.Spacing.sm)
        ]
    }

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            ScrollView {
                VStack(spacing: KamihiTheme.Spacing.lg) {
                    headerSection
                    featuredDesktopCard

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
    }

    private var headerSection: some View {
        VStack(spacing: KamihiTheme.Spacing.xs) {
            Text("KAMIHI DESKTOP")
                .font(.caption.weight(.bold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0.8 : 2.2)
                .foregroundStyle(.tint)

            Text("Your iPhone desktop")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Connect RayNeo or another external display and use the iPhone as the trackpad, keyboard, launcher, and secure touch surface.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .combine)
    }

    private var featuredDesktopCard: some View {
        HStack(alignment: .top, spacing: KamihiTheme.Spacing.md) {
            Image(systemName: "display.2")
                .font(.title.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("One desktop. Use it however you want.")
                    .font(.headline)
                Text("No forced coding layout and no separate Mac-remote product in the normal app flow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(KamihiTheme.Spacing.md)
        .frame(maxWidth: 560)
        .background(
            reduceTransparency ? AnyShapeStyle(Color(uiColor: .secondarySystemBackground)) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
        )
        .accessibilityElement(children: .combine)
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
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        .accessibilityHidden(true)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 54,
                        alignment: .topLeading
                    )
            }
            .padding(14)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 150,
                alignment: .topLeading
            )
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
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("\(profile.subtitle) Opens Kamihi Desktop with this starting layout.")
    }
}
