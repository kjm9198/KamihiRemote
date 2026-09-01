import SwiftUI

/// Local debugging and simulator test lab.
/// Renders a true 16:9 simulation of the external desktop alongside the phone
/// controller, both driven by the exact same DesktopSession.
struct DesktopLabView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height

            Group {
                if landscape {
                    HStack(spacing: 0) {
                        desktopPreview
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(10)

                        Divider()
                            .overlay(Color.primary.opacity(0.12))

                        controllerSection
                            .frame(width: max(320, geo.size.width * 0.38))
                    }
                } else {
                    VStack(spacing: 0) {
                        desktopPreview
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 6)

                        Divider()
                            .overlay(Color.primary.opacity(0.12))

                        controllerSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(KamihiTheme.Colors.surfaceBackground.ignoresSafeArea())
        .onAppear {
            bootDesktopIfNeeded()
        }
    }

    private var desktopPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)

            desktopSection
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.8)
                }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }

    private var desktopSection: some View {
        ZStack(alignment: .topLeading) {
            ExternalDesktopCanvasView()
                .environmentObject(desktop)

            HStack(spacing: 5) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("Desktop Lab")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)
        }
    }

    private var controllerSection: some View {
        DesktopControllerView()
            .environmentObject(router)
            .environmentObject(desktop)
    }

    @MainActor
    private func bootDesktopIfNeeded() {
        guard desktop.windows.isEmpty else { return }

        if !DesktopFeatureState.shared.restoreSession(desktop: desktop) {
            desktop.openVibeWorkspace()
        }
    }
}
