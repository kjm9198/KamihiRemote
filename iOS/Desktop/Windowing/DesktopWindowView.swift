import SwiftUI

/// Centralized render policy for desktop window contents.
///
/// Minimized windows should not keep expensive WebKit/media surfaces alive behind
/// a fully transparent window. Under explicit battery saving, iOS Low Power Mode,
/// or serious/critical thermal pressure, inactive web-backed windows are also
/// released until the user activates them again. Their URLs/session metadata and
/// WebKit website data remain persisted by the owning app/state stores.
enum DesktopWindowEnergyPolicy {
    static func shouldRenderContent(
        isMinimized: Bool,
        isActive: Bool,
        isWebBacked: Bool,
        shouldConserveEnergy: Bool
    ) -> Bool {
        guard !isMinimized else { return false }
        if shouldConserveEnergy && isWebBacked && !isActive {
            return false
        }
        return true
    }

    static func isWebBackedApp(_ title: String) -> Bool {
        switch title {
        case "Browser", "ChatGPT", "YouTube":
            return true
        default:
            return false
        }
    }
}

/// Renders an iPadOS-inspired Kamihi desktop window on the external screen.
/// Window buttons remain directly tappable in Desktop Lab, while physical
/// external-display use routes the same actions through DesktopWindowChrome.
struct DesktopWindowView<Content: View>: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared

    let window: DesktopSession.DesktopWindow
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let frame = effectiveFrame(in: geo.size)

            VStack(spacing: 0) {
                titleBar
                    .frame(height: 38)
                    .background(.ultraThinMaterial)

                Group {
                    if shouldRenderContent {
                        content()
                    } else {
                        // Intentionally lightweight: do not retain a hidden WKWebView,
                        // media pipeline, or app-specific timer while this window sleeps.
                        Color.clear
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KamihiTheme.Colors.surfaceBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.primary.opacity(0.26) : Color.primary.opacity(0.10),
                        lineWidth: isActive ? 1.1 : 0.7
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if isActive && !window.isMaximized {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
            .shadow(
                color: Color.black.opacity(isActive ? 0.34 : 0.18),
                radius: isActive ? 18 : 9,
                x: 0,
                y: isActive ? 9 : 4
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .scaleEffect(window.isMinimized ? 0.70 : 1.0)
            .opacity(window.isMinimized ? 0.0 : 1.0)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.isMinimized)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.isMaximized)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.normalizedFrame)
        }
    }

    private var shouldRenderContent: Bool {
        // Observing `power` makes the body re-evaluate immediately when iOS reports
        // Low Power Mode or thermal-state changes. `features` covers the manual
        // Battery Saver override. Reading shouldConserveEnergy keeps one policy
        // source of truth for the whole desktop.
        _ = power.lowPowerMode
        _ = power.thermalState
        return DesktopWindowEnergyPolicy.shouldRenderContent(
            isMinimized: window.isMinimized,
            isActive: isActive,
            isWebBacked: DesktopWindowEnergyPolicy.isWebBackedApp(window.title),
            shouldConserveEnergy: features.shouldConserveEnergy
        )
    }

    private var titleBar: some View {
        HStack(spacing: 9) {
            Image(systemName: appIcon(for: window.title))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(isActive ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(window.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 5) {
                chromeButton(
                    symbol: "minus",
                    accessibilityLabel: "Minimize \(window.title)"
                ) {
                    desktop.minimize(window.id)
                }

                chromeButton(
                    symbol: window.isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: window.isMaximized ? "Restore \(window.title)" : "Maximize \(window.title)"
                ) {
                    desktop.toggleMaximize(window.id)
                }

                chromeButton(
                    symbol: "xmark",
                    accessibilityLabel: "Close \(window.title)"
                ) {
                    desktop.close(window.id)
                }
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 8)
    }

    private func chromeButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary.opacity(isActive ? 0.82 : 0.52))
                .frame(width: 27, height: 27)
                .background(Color.primary.opacity(isActive ? 0.075 : 0.035), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var windowCornerRadius: CGFloat {
        window.isMaximized ? KamihiTheme.Radius.sm : KamihiTheme.Radius.md
    }

    private func effectiveFrame(in containerSize: CGSize) -> CGRect {
        let normalized = desktop.effectiveFrame(for: window)
        return CGRect(
            x: normalized.origin.x * containerSize.width,
            y: normalized.origin.y * containerSize.height,
            width: normalized.width * containerSize.width,
            height: normalized.height * containerSize.height
        )
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
        default: return "app.fill"
        }
    }
}
