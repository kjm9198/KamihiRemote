import SwiftUI

/// Renders the complete desktop environment on the external display (or simulated in Desktop Lab).
struct ExternalDesktopCanvasView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var settings = TrackpadSettings.shared
    @State private var showLauncher = false

    var body: some View {
        ZStack {
            // Desktop Wallpaper
            KamihiTheme.AtmosphericBackground()

            // Desktop Windows Layer
            ForEach(desktop.windows) { window in
                DesktopWindowView(
                    window: window,
                    isActive: desktop.activeWindowID == window.id
                ) {
                    windowContent(for: window.title)
                }
            }

            // Bottom Dock
            VStack {
                Spacer()
                DesktopDockView(onOpenLauncher: { showLauncher.toggle() })
                    .padding(.bottom, 12)
            }

            // Software Cursor
            DesktopCursorView(
                cursorPosition: desktop.cursor,
                cursorStyle: settings.cursorStyle,
                interactionState: desktop.isDraggingWindow ? .dragging : .defaultState
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if showLauncher {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showLauncher = false }

                DesktopAppLauncherView()
                    .environmentObject(desktop)
                    .frame(maxWidth: 600, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.lg, style: .continuous))
                    .shadow(radius: 24)
            }
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
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
