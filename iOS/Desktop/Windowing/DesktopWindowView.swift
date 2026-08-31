import SwiftUI

/// Renders a native Apple-style desktop window on the external screen.
struct DesktopWindowView<Content: View>: View {
    @EnvironmentObject private var desktop: DesktopSession
    let window: DesktopSession.DesktopWindow
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let frame = effectiveFrame(in: geo.size)

            VStack(spacing: 0) {
                // Window Title Bar
                titleBar
                    .frame(height: 38)
                    .background(
                        isActive ? Color(red: 0.16, green: 0.18, blue: 0.24) : Color(red: 0.11, green: 0.12, blue: 0.16)
                    )

                // Window Content Area
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.07, green: 0.08, blue: 0.11))
            }
            .clipShape(RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KamihiTheme.Radius.md, style: .continuous)
                    .strokeBorder(isActive ? Color.cyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: isActive ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(isActive ? 0.45 : 0.25), radius: isActive ? 20 : 10, x: 0, y: isActive ? 10 : 4)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .scaleEffect(window.isMinimized ? 0.2 : 1.0)
            .opacity(window.isMinimized ? 0.0 : 1.0)
            .animation(KamihiTheme.Animation.spatial, value: window.isMinimized)
            .animation(KamihiTheme.Animation.spatial, value: window.isMaximized)
            .animation(KamihiTheme.Animation.spatial, value: window.normalizedFrame)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            // Traffic Light Window Controls
            HStack(spacing: 7) {
                // Close
                Circle()
                    .fill(Color(red: 1.0, green: 0.36, blue: 0.33))
                    .frame(width: 12, height: 12)
                    .onTapGesture { desktop.close(window.id) }

                // Minimize
                Circle()
                    .fill(Color(red: 1.0, green: 0.76, blue: 0.22))
                    .frame(width: 12, height: 12)
                    .onTapGesture { desktop.minimize(window.id) }

                // Maximize / Restore
                Circle()
                    .fill(Color(red: 0.18, green: 0.80, blue: 0.38))
                    .frame(width: 12, height: 12)
                    .onTapGesture { desktop.toggleMaximize(window.id) }
            }
            .padding(.leading, 12)

            Spacer()

            // App Icon + Title
            HStack(spacing: 6) {
                Image(systemName: appIcon(for: window.title))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? Color.cyan : Color.white.opacity(0.6))

                Text(window.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Right spacer to center title
            Color.clear
                .frame(width: 52, height: 12)
        }
    }

    private func effectiveFrame(in containerSize: CGSize) -> CGRect {
        if window.isMaximized {
            let maxFrame = WindowSnapEngine.frame(for: .maximize)
            return CGRect(
                x: maxFrame.origin.x * containerSize.width,
                y: maxFrame.origin.y * containerSize.height,
                width: maxFrame.width * containerSize.width,
                height: maxFrame.height * containerSize.height
            )
        } else {
            return CGRect(
                x: window.normalizedFrame.origin.x * containerSize.width,
                y: window.normalizedFrame.origin.y * containerSize.height,
                width: window.normalizedFrame.width * containerSize.width,
                height: window.normalizedFrame.height * containerSize.height
            )
        }
    }

    private func appIcon(for title: String) -> String {
        switch title {
        case "Browser": return "globe"
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Notes": return "note.text"
        case "Files": return "folder.fill"
        case "Calculator": return "plus.slash.minus"
        case "Clipboard": return "doc.on.clipboard.fill"
        default: return "app.window.checkmark"
        }
    }
}
