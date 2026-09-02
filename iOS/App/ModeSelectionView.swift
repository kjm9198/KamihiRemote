import SwiftUI

/// Desktop-first launch experience. Startup choices are layouts, not separate products.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
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
                            .accessibilityAddTraits(.isHeader)

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
                    .frame(maxWidth: 560, minHeight: 44)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .accessibilityHint("Opens the deterministic desktop preview used for visual verification.")
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
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var featuredDesktopCard: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KamihiTheme.Spacing.sm) {
                featuredDesktopIcon
                featuredDesktopCopy
            }
            .modifier(FeaturedDesktopCardStyle(reduceTransparency: reduceTransparency))
        } else {
            HStack(alignment: .top, spacing: KamihiTheme.Spacing.md) {
                featuredDesktopIcon
                featuredDesktopCopy
                Spacer(minLength: 0)
            }
            .modifier(FeaturedDesktopCardStyle(reduceTransparency: reduceTransparency))
        }
    }

    private var featuredDesktopIcon: some View {
        Image(systemName: "display.2")
            .font(.title.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }

    private var featuredDesktopCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("One desktop. Use it however you want.")
                .font(.headline)
            Text("No forced coding layout and no separate Mac-remote product in the normal app flow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func profileCard(_ profile: DesktopLaunchProfile) -> some View {
        let isSelected = selectedProfile == profile
        let shortcut = keyboardShortcut(for: profile)

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
                        Image(systemName: differentiateWithoutColor ? "checkmark.seal.fill" : "checkmark.circle.fill")
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

                if differentiateWithoutColor || dynamicTypeSize.isAccessibilitySize {
                    Text("⌘\(shortcut.character)")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 88 : 150,
                alignment: .topLeading
            )
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: .command)
        .accessibilityLabel(profile.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("\(profile.subtitle) Opens Kamihi Desktop with this starting layout. Hardware keyboard shortcut Command \(shortcut.character).")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func keyboardShortcut(for profile: DesktopLaunchProfile) -> KeyEquivalent {
        switch profile {
        case .clean: return "1"
        case .resume: return "2"
        case .work: return "3"
        case .browse: return "4"
        case .media: return "5"
        case .vibe: return "6"
        }
    }
}

private struct FeaturedDesktopCardStyle: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        content
            .padding(KamihiTheme.Spacing.md)
            .frame(maxWidth: 560, alignment: .leading)
            .background(
                reduceTransparency ? AnyShapeStyle(Color(uiColor: .secondarySystemBackground)) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
            )
            .accessibilityElement(children: .combine)
    }
}
