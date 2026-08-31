import SwiftUI

/// Bottom toolbar on the phone controller that contextually morphs based on the active desktop application.
struct ContextualControllerToolbar: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject var engine: TrackpadEngine

    var onOpenLauncher: () -> Void
    var onOpenOverview: () -> Void
    var onOpenCommandPalette: () -> Void
    var onToggleKeyboard: () -> Void
    var onContinueOnPhone: (UUID) -> Void

    var body: some View {
        HStack(spacing: KamihiTheme.Spacing.xs) {
            // General utilities always available on the left
            Button(action: onToggleKeyboard) {
                Image(systemName: "keyboard")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Keyboard")

            Button(action: onOpenLauncher) {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Apps")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel("App Launcher")

            Spacer(minLength: 4)

            // Contextual center actions
            contextualActions

            Spacer(minLength: 4)

            // Precision mode toggle
            Button {
                engine.isPrecisionMode.toggle()
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
            } label: {
                Image(systemName: engine.isPrecisionMode ? "scope" : "circle.dotted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(engine.isPrecisionMode ? Color.cyan : Color.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Precision Mode")

            // Command palette / More
            Button(action: onOpenCommandPalette) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Command Palette and Actions")
        }
        .padding(.horizontal, KamihiTheme.Spacing.sm)
        .padding(.vertical, KamihiTheme.Spacing.xs)
    }

    @ViewBuilder
    private var contextualActions: some View {
        if let active = desktop.activeWindow {
            switch active.title {
            case "Browser":
                browserToolbar(windowID: active.id)
            case "YouTube":
                youtubeToolbar(windowID: active.id)
            case "ChatGPT":
                chatGPTToolbar(windowID: active.id)
            case "Notes":
                notesToolbar
            default:
                defaultAppToolbar(windowID: active.id)
            }
        } else {
            defaultAppToolbar(windowID: nil)
        }
    }

    private func browserToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            Button {
                desktop.goBackInActiveBrowser()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .circle)

            Button {
                desktop.goForwardInActiveBrowser()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .circle)

            Button {
                onContinueOnPhone(windowID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "iphone.and.arrow.forward")
                    Text("Phone")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.cyan)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private func youtubeToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            Button {
                desktop.clickAtCursor()
            } label: {
                Image(systemName: "playpause.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .circle)

            Button {
                onContinueOnPhone(windowID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "iphone.and.arrow.forward")
                    Text("Phone")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.cyan)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private func chatGPTToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            Button {
                onToggleKeyboard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.cursor.ibeam")
                    Text("Prompt")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .capsule)

            Button {
                onContinueOnPhone(windowID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "iphone.and.arrow.forward")
                    Text("Phone")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.cyan)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private var notesToolbar: some View {
        HStack(spacing: 6) {
            Button {
                onToggleKeyboard()
            } label: {
                Image(systemName: "pencil.line")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private func defaultAppToolbar(windowID: UUID?) -> some View {
        HStack(spacing: 6) {
            Button(action: onOpenOverview) {
                Image(systemName: "square.2.layers.3d.top.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.85))
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Window Overview")
        }
    }
}
