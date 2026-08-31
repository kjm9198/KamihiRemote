import SwiftUI

/// Local debugging and simulator test lab.
/// Renders a 16:9 simulation of the external desktop alongside the phone controller,
/// both driven by the exact same DesktopSession for interactive testing on Mac/Simulator.
struct DesktopLabView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height

            Group {
                if landscape {
                    HStack(spacing: 0) {
                        // Left: 16:9 External Desktop Canvas
                        desktopSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider().background(Color.white.opacity(0.2))

                        // Right: Live Phone Controller
                        controllerSection
                            .frame(width: max(320, geo.size.width * 0.38))
                    }
                } else {
                    VStack(spacing: 0) {
                        // Top: 16:9 External Desktop Canvas
                        desktopSection
                            .frame(height: max(220, geo.size.height * 0.38))

                        Divider().background(Color.white.opacity(0.2))

                        // Bottom: Live Phone Controller
                        controllerSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var desktopSection: some View {
        ZStack(alignment: .topLeading) {
            ExternalDesktopCanvasView()
                .environmentObject(desktop)

            // Header Banner
            HStack(spacing: 6) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Desktop Lab (16:9 Simulation)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.75), in: Capsule())
            .padding(10)
        }
    }

    private var controllerSection: some View {
        DesktopControllerView()
            .environmentObject(router)
            .environmentObject(desktop)
    }
}
