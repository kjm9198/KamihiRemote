import SwiftUI

/// Compact, thumb-first toolbar for Kamihi Desktop.
/// The trackpad remains the primary surface; this rail only exposes actions that
/// are useful immediately for the active app.
struct ContextualControllerToolbar: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject var engine: TrackpadEngine
    @ScaledMetric(relativeTo: .body) private var scaledControlSize: CGFloat = 44

    var onOpenLauncher: () -> Void
    var onOpenOverview: () -> Void
    var onOpenCommandPalette: () -> Void
    var onToggleKeyboard: () -> Void
    var onContinueOnPhone: (UUID) -> Void

    private var controlSize: CGFloat {
        min(max(scaledControlSize, 44), 58)
    }

    private var symbolSize: CGFloat {
        min(max(controlSize * 0.36, 16), 20)
    }

    var body: some View {
        HStack(spacing: 7) {
            compactButton(
                symbol: "keyboard",
                label: "Keyboard",
                hint: "Shows or hides the phone keyboard for the active desktop app.",
                action: onToggleKeyboard
            )

            compactButton(
                symbol: "square.grid.2x2.fill",
                label: "App Launcher",
                hint: "Opens the Kamihi Desktop app launcher.",
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
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(engine.isPrecisionMode ? Color.accentColor : Color.primary.opacity(0.82))
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(engine.isPrecisionMode ? "Disable Precision Mode" : "Enable Precision Mode")
            .accessibilityValue(engine.isPrecisionMode ? "On" : "Off")
            .accessibilityHint("Precision Mode reduces pointer speed for small desktop targets.")

            compactButton(
                symbol: "ellipsis",
                label: "Command Palette and Actions",
                hint: "Opens searchable desktop commands and additional actions.",
                action: onOpenCommandPalette
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minHeight: controlSize + 8)
        .accessibilityElement(children: .contain)
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
            compactButton(symbol: "chevron.left", label: "Back", hint: "Goes to the previous page in the active browser.") {
                desktop.goBackInActiveBrowser()
            }

            compactButton(symbol: "chevron.right", label: "Forward", hint: "Goes to the next page in the active browser.") {
                desktop.goForwardInActiveBrowser()
            }

            phoneButton(windowID: windowID)
        }
    }

    private func youtubeToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            compactButton(symbol: "playpause.fill", label: "Play or Pause", hint: "Activates the current playback control at the desktop pointer.") {
                desktop.clickAtCursor()
            }

            phoneButton(windowID: windowID)
        }
    }

    private func chatGPTToolbar(windowID: UUID) -> some View {
        HStack(spacing: 6) {
            compactButton(symbol: "character.cursor.ibeam", label: "Prompt Keyboard", hint: "Opens the phone keyboard for the ChatGPT prompt.") {
                onToggleKeyboard()
            }

            phoneButton(windowID: windowID)
        }
    }

    private var notesToolbar: some View {
        HStack(spacing: 6) {
            compactButton(symbol: "pencil.line", label: "Edit Note", hint: "Opens the phone keyboard for the current note.") {
                onToggleKeyboard()
            }
        }
    }

    private func defaultAppToolbar(windowID: UUID?) -> some View {
        HStack(spacing: 6) {
            compactButton(
                symbol: "square.2.layers.3d.top.filled",
                label: "Window Overview",
                hint: "Shows all open Kamihi Desktop windows.",
                action: onOpenOverview
            )
        }
    }

    private func compactButton(
        symbol: String,
        label: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.86))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }

    private func phoneButton(windowID: UUID) -> some View {
        Button {
            onContinueOnPhone(windowID)
        } label: {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: controlSize, height: controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Continue on iPhone")
        .accessibilityHint("Temporarily opens the active app on the phone for touch, typing, or authentication.")
    }
}
