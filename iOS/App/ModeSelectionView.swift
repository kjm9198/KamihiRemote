import SwiftUI

/// The launch experience of Kamihi: a clean, Apple-native Mode Chooser.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            VStack(spacing: KamihiTheme.Spacing.lg) {
                topBar
                Spacer(minLength: 0)
                headerSection
                Spacer(minLength: 0)
                cardsSection
                Spacer(minLength: 0)
                footerSection
            }
            .padding(.horizontal, KamihiTheme.Spacing.lg)
            .padding(.vertical, KamihiTheme.Spacing.md)
        }
        .sheet(isPresented: $router.showsSettings) {
            SettingsSheet().environmentObject(session)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                router.showsSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(KamihiTheme.Spacing.sm)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var headerSection: some View {
        VStack(spacing: KamihiTheme.Spacing.xs) {
            Text("KAMIHI")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(Color.cyan.opacity(0.9))

            Text("What would you like to use?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var cardsSection: some View {
        VStack(spacing: KamihiTheme.Spacing.md) {
            modeCard(
                mode: .remoteMac,
                badge: "Mac Control",
                title: "Remote for Mac",
                description: "Control your MacBook trackpad, keyboard, and apps from your iPhone.",
                gradient: [Color(red: 0.12, green: 0.28, blue: 0.48), Color(red: 0.08, green: 0.16, blue: 0.28)],
                icon: "laptopcomputer.and.iphone"
            ) {
                router.selectMode(.remoteMac)
            }

            modeCard(
                mode: .externalDesktop,
                badge: "External Display",
                title: "Kamihi Desktop",
                description: "Turn AR glasses or external monitors into an interactive workspace.",
                gradient: [Color(red: 0.28, green: 0.14, blue: 0.44), Color(red: 0.14, green: 0.08, blue: 0.26)],
                icon: "display.2"
            ) {
                router.selectMode(.externalDesktop)
            }
        }
        .frame(maxWidth: 440)
    }

    private func modeCard(
        mode: AppMode,
        badge: String,
        title: String,
        description: String,
        gradient: [Color],
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KamihiTheme.Spacing.sm) {
                HStack {
                    Text(badge.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12), in: Capsule())

                    Spacer()

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Open")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.18), in: Capsule())
                }
                .padding(.top, 4)
            }
            .padding(KamihiTheme.Spacing.md)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }

    private var footerSection: some View {
        HStack(spacing: KamihiTheme.Spacing.md) {
            #if DEBUG
            Button {
                router.startDesktopLab()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flask.fill")
                    Text("Desktop Lab (Simulator)")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.cyan.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            #endif
        }
    }
}
