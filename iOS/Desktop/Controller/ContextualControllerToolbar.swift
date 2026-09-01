import SwiftUI

/// Compact, thumb-first toolbar for Kamihi Desktop.
/// The trackpad remains the primary surface; this rail only exposes actions that
/// are useful immediately for the active app.
struct ContextualControllerToolbar: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject var engine: TrackpadEngine

    var onOpenLauncher: () -> Void
    var onOpenOverview: () -> Void
    var onOpenCommandPalette: () -> Void
    var onToggleKeyboard: () -> Void
    var onContinueOnPhone: (UUID) -> Void

    var body: some View {
        HStack(spacing: 7) {
            compactButton(
                symbol: "keyboard",
                label: "Keyboard",
                action: onToggleKeyboard
            )

            compactButton(
                symbol: "square.grid.2x2.fill",
                label: "App Launcher",
                action: onOpenLauncher
            )

            Spacer(minLength: 2)

            contextualActions

            Spacer(minLength: 2)

            Button {
                engine.isPrecisionMode.toggle()
                if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
            } label: {
                Image(systemName: engine.isPrecisionMode ? "scope" : "circle.dotted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(engine.isPrecisionMode ? Color.accentColor : Color.primary.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(engine.isPrecisionMode ? "Disable Precision Mode" : "Enable Precision Mode")
            .accessibilityValue(engine.isPrecisionMode ? "On" : "Off")

            compactButton(
                symbol: "ellipsis",
                label: "Command Palette and Actions",
                action: onOpenCommandPalette
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minHeight: 52)
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
            compactButton(symbol: "chevron.left", label: "Back") {
                desktop.goBackInActiveBrowser()
            }

            compactButton(symbol: "chevron.right", label: "Forward") {
                desktop.goForwardInActiveBrowser()
            }

            phoneButton(windowID: windowID)
        }
    }

    private func youtubeToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            compactButton(symbol: "playpause.fill", label: "Play or Pause") {
                desktop.clickAtCursor()
            }

            phoneButton(windowID: windowID)
        }
    }

    private func chatGPTToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            compactButton(symbol: "character.cursor.ibeam", label: "Prompt Keyboard") {
                onToggleKeyboard()
            }

            phoneButton(windowID: windowID)
        }
    }

    private var notesToolbar: some View {
        HStack(spacing: 6) {
            compactButton(symbol: "pencil.line", label: "Edit Note") {
                onToggleKeyboard()
            }
        }
    }

    private func defaultAppToolbar(windowID: UUID?) -> some View {
        HStack(spacing: 6) {
            compactButton(
                symbol: "square.2.layers.3d.top.filled",
                label: "Window Overview",
                action: onOpenOverview
            )
        }
    }

    private func compactButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.86))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }

    private func phoneButton(windowID: UUID) -> some View {
        Button {
            onContinueOnPhone(windowID)
        } label: {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Continue on iPhone")
        .accessibilityHint("Temporarily opens the active app on the phone for touch, typing, or authentication")
    }
}
