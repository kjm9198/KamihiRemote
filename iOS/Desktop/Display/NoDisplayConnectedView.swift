import SwiftUI

/// Displayed on the iPhone when Kamihi Desktop is selected without an active external monitor.
struct NoDisplayConnectedView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var desktop: DesktopSession
    @State private var showDiagnostics = false

    var body: some View {
        ZStack {
            KamihiTheme.AtmosphericBackground()

            VStack(spacing: KamihiTheme.Spacing.lg) {
                // Top navigation
                HStack {
                    Button {
                        router.returnToChooser()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Modes")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, KamihiTheme.Spacing.md)
                .padding(.top, 8)

                Spacer(minLength: 0)

                // Central Illustration & Guidance
                VStack(spacing: KamihiTheme.Spacing.md) {
                    Image(systemName: "display.2")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 8)

                    Text("Connect Your External Display")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Plug in your USB-C display or RayNeo Air 4 Pro glasses to start your spatial desktop environment.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 0)

                // Actions
                VStack(spacing: KamihiTheme.Spacing.sm) {
                    Button {
                        router.startDesktopLab()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "flask.fill")
                            Text("Preview Desktop (Lab Mode)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDiagnostics = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg.rectangle")
                            Text("Display Diagnostics")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, KamihiTheme.Spacing.lg)
                .padding(.bottom, KamihiTheme.Spacing.lg)
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            DesktopDiagnosticsPhoneView()
        }
    }
}
