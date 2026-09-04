import SwiftUI

/// Kamihi Desktop has one normal product flow: enter the desktop and continue
/// from the last saved session. The legacy launch-profile identifiers remain in
/// the codebase only for compatibility with existing persisted user data.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            ScrollView {
                VStack(spacing: KamihiTheme.Spacing.lg) {
                    headerSection
                    desktopCard

                    Button {
                        // One desktop. Restore what the user left behind when a
                        // recovery snapshot exists; a first run naturally opens
                        // to an empty desktop because there is nothing to restore.
                        DesktopLaunchProfile.selected = .resume
                        router.selectMode(.externalDesktop)
                    } label: {
                        Label("Enter Desktop", systemImage: "rectangle.inset.filled.and.person.filled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: 560, minHeight: 52)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityHint("Opens your single Kamihi Desktop and restores the windows you left open when available.")

                    Text("Kamihi remembers the windows you leave open. On a new or cleared session the desktop starts empty, and nothing opens until you choose an app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)

                    #if DEBUG
                    Button {
                        DesktopLaunchProfile.selected = .resume
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

            Text("Connect RayNeo or another external display. Your iPhone becomes the trackpad, keyboard, launcher, and secure touch surface.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var desktopCard: some View {
        HStack(alignment: .top, spacing: KamihiTheme.Spacing.md) {
            Image(systemName: "display.2")
                .font(.title.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("One desktop")
                    .font(.headline)
                Text("No modes and no presets. Continue from what you left behind, or start from an empty desktop when there is no saved session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(KamihiTheme.Spacing.md)
        .frame(maxWidth: 560, alignment: .leading)
        .background(
            reduceTransparency ? AnyShapeStyle(Color(uiColor: .secondarySystemBackground)) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
