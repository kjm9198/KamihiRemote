import SwiftUI

/// Renders the complete desktop environment on the external display (or simulated in Desktop Lab).
struct ExternalDesktopCanvasView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var settings = TrackpadSettings.shared
    @StateObject private var display = ExternalDisplayCoordinator.shared
    @StateObject private var appearance = DesktopAppearanceSettings.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @State private var showLauncher = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { outer in
            let insets = display.safeInsets(for: outer.size)

            ZStack {
                KamihiTheme.AtmosphericBackground()
                    .ignoresSafeArea()

                desktopSurface
                    .padding(.top, insets.top)
                    .padding(.leading, insets.leading)
                    .padding(.bottom, insets.bottom)
                    .padding(.trailing, insets.trailing)
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
    }

    private var desktopSurface: some View {
        ZStack {
            if let target = desktop.snapPreviewTarget {
                snapPreview(for: target)
                    .transition(.opacity)
                    .zIndex(1)
            }

            ForEach(desktop.windows) { window in
                DesktopWindowView(
                    window: window,
                    isActive: desktop.activeWindowID == window.id
                ) {
                    windowContent(for: window.title)
                }
                .zIndex(desktop.activeWindowID == window.id ? 4 : 2)
            }

            VStack {
                Spacer()
                DesktopDockView(onOpenLauncher: { showLauncher.toggle() })
                    .padding(.bottom, 12)
            }
            .zIndex(6)

            DesktopCursorView(
                cursorPosition: desktop.cursor,
                cursorStyle: settings.cursorStyle,
                interactionState: desktop.cursorInteractionState
            )
            .zIndex(20)
        }
        .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: desktop.snapPreviewTarget)
        .animation(shouldSuppressDecorativeMotion ? nil : KamihiTheme.Animation.fast, value: showLauncher)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Rectangle())
        .overlay {
            if showLauncher {
                (colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.18))
                    .onTapGesture { showLauncher = false }

                DesktopAppLauncherView()
                    .environmentObject(desktop)
                    .frame(maxWidth: 600, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))
                    .shadow(
                        color: .black.opacity(shouldSuppressDecorativeMotion ? 0 : (colorScheme == .dark ? 0.35 : 0.18)),
                        radius: shouldSuppressDecorativeMotion ? 0 : 24,
                        y: shouldSuppressDecorativeMotion ? 0 : 12
                    )
            }
        }
        .overlay {
            if display.horizontalSafeMargin > 0 || display.verticalSafeMargin > 0 {
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Treat system Low Power Mode and serious/critical thermal pressure like
    /// Reduce Motion for purely decorative desktop effects. Pointer movement,
    /// window manipulation and WebKit remain responsive; only non-essential
    /// transition/shadow work is suppressed until the system constraint clears.
    private var shouldSuppressDecorativeMotion: Bool {
        reduceMotion || power.lowPowerMode || power.thermalState == .serious || power.thermalState == .critical
    }

    private func snapPreview(for target: WindowSnapEngine.SnapTarget) -> some View {
        GeometryReader { geo in
            let normalized = WindowSnapEngine.frame(for: target)
            let frame = CGRect(
                x: normalized.minX * geo.size.width,
                y: normalized.minY * geo.size.height,
                width: normalized.width * geo.size.width,
                height: normalized.height * geo.size.height
            )

            RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.30), lineWidth: 1.5)
                )
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func windowContent(for title: String) -> some View {
        switch title {
        case "Browser":
            DesktopBrowserView()
        case "ChatGPT":
            DesktopChatGPTView()
        case "YouTube":
            DesktopYouTubeView()
        case "Notes":
            DesktopNotesView()
        case "Files":
            DesktopFilesView()
        default:
            VStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KamihiTheme.Colors.surfaceBackground)
        }
    }
}
