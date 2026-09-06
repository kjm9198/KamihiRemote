import SwiftUI

/// First-run entry into the one persistent Kamihi Desktop. After this first entry
/// the router resumes Desktop automatically on normal launches.
struct ModeSelectionView: View {
    @EnvironmentObject private var router: AppModeRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 26)
                hero
                desktopCard
                enterButton

                #if DEBUG
                Button {
                    DesktopLaunchProfile.selected = .resume
                    router.startDesktopLab()
                } label: {
                    Label("Desktop Lab", systemImage: "flask.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .desktopGlassSurface(cornerRadius: 19, elevated: false)
                .keyboardShortcut("d", modifiers: [.command, .shift])
                #endif

                Text("After you enter once, Kamihi returns directly to this desktop and restores your last session whenever possible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 20)

                Spacer(minLength: 26)
            }
            .padding(.horizontal, 24)
        }
    }

    private var hero: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.95), Color.purple.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(0.18), radius: 14, y: 8)
                Image(systemName: "display.2")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Kamihi Desktop")
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 32 : 38, weight: .bold))
                .tracking(-1.1)

            Text("A persistent desktop powered entirely by your iPhone")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var desktopCard: some View {
        VStack(spacing: 0) {
            featureRow("display", title: "External desktop", detail: "RayNeo or any supported display becomes the desktop canvas.")
            Divider().opacity(0.35)
            featureRow("rectangle.3.group", title: "Persistent windows", detail: "Apps, positions and the active window resume after reconnect or relaunch.")
            Divider().opacity(0.35)
            featureRow("iphone.gen3", title: "iPhone control surface", detail: "Trackpad, keyboard, settings and secure system prompts stay on the phone.")
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 580)
        .desktopGlassSurface(cornerRadius: 22)
    }

    private func featureRow(_ icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var enterButton: some View {
        Button {
            DesktopLaunchProfile.selected = .resume
            router.selectMode(.externalDesktop)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                Text("Enter Desktop")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.7)
            }
            .shadow(color: Color.accentColor.opacity(0.22), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 580)
        .keyboardShortcut(.return, modifiers: [])
        .accessibilityHint("Enters your persistent Kamihi Desktop and restores the previous session when available.")
    }
}
