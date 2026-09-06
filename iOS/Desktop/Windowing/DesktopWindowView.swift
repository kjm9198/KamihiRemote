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
        shouldConserveEnergy: Bool,
        hasExceededIdleRetention: Bool = false
    ) -> Bool {
        guard !isMinimized else { return false }
        if isWebBacked && !isActive && (shouldConserveEnergy || hasExceededIdleRetention) {
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

/// Renders a macOS-inspired Kamihi desktop window on the external screen.
/// Window buttons remain directly tappable in Desktop Lab, while physical
/// external-display use routes the same actions through DesktopWindowChrome.
struct DesktopWindowView<Content: View>: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var features = DesktopFeatureState.shared
    @StateObject private var power = DesktopPowerMonitor.shared
    @State private var hasExceededIdleRetention = false
    @State private var idleRetentionTask: Task<Void, Never>?

    let window: DesktopSession.DesktopWindow
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    private let inactiveWebRetentionNanoseconds: UInt64 = 15 * 60 * 1_000_000_000

    var body: some View {
        GeometryReader { geo in
            let frame = effectiveFrame(in: geo.size)

            VStack(spacing: 0) {
                titleBar
                    .frame(height: 38)
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.primary.opacity(isActive ? 0.10 : 0.055))
                                    .frame(height: 0.5)
                            }
                    }

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
                .background(KamihiTheme.Colors.surfaceBackground.opacity(0.94))
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.white.opacity(0.30) : Color.primary.opacity(0.10),
                        lineWidth: isActive ? 0.9 : 0.6
                    )
            }
            .overlay {
                if isActive && !window.isMaximized {
                    DesktopResizeAffordances(activeEdge: desktop.resizeEdgeAtCursor())
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .shadow(
                color: Color.black.opacity(isActive ? 0.30 : 0.16),
                radius: isActive ? 22 : 12,
                x: 0,
                y: isActive ? 12 : 6
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            // A dock-directed shrink gives minimize/restore a much closer macOS
            // spatial feel than simply fading the window in place.
            .scaleEffect(window.isMinimized ? 0.78 : 1.0)
            .offset(y: window.isMinimized ? max(42, geo.size.height * 0.22) : 0)
            .opacity(window.isMinimized ? 0.0 : 1.0)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.isMinimized)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.isMaximized)
            .animation(reduceMotion ? nil : KamihiTheme.Animation.spatial, value: window.normalizedFrame)
        }
        .onAppear {
            updateIdleRetentionPolicy()
        }
        .onChange(of: isActive) { _, _ in
            updateIdleRetentionPolicy()
        }
        .onChange(of: window.isMinimized) { _, _ in
            updateIdleRetentionPolicy()
        }
        .onDisappear {
            idleRetentionTask?.cancel()
            idleRetentionTask = nil
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
            shouldConserveEnergy: features.shouldConserveEnergy,
            hasExceededIdleRetention: hasExceededIdleRetention
        )
    }

    /// Keep normal app switching instant, but do not retain an inactive browser,
    /// ChatGPT, or YouTube renderer forever during an otherwise unconstrained long
    /// desktop session. This is a single self-terminating sleep per inactive window,
    /// not a polling timer/display link. Reactivation cancels it immediately and
    /// recreates the web surface from the app's persisted URL/session metadata.
    private func updateIdleRetentionPolicy() {
        idleRetentionTask?.cancel()
        idleRetentionTask = nil

        let isWebBacked = DesktopWindowEnergyPolicy.isWebBackedApp(window.title)
        guard isWebBacked, !isActive, !window.isMinimized else {
            hasExceededIdleRetention = false
            return
        }

        hasExceededIdleRetention = false
        idleRetentionTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: inactiveWebRetentionNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            hasExceededIdleRetention = true
            idleRetentionTask = nil
        }
    }

    private var titleBar: some View {
        ZStack {
            HStack(spacing: 0) {
                trafficLights
                Spacer(minLength: 12)
                // Balance the left chrome so the app title remains optically centered.
                Color.clear.frame(width: 64, height: 1)
            }

            HStack(spacing: 6) {
                Image(systemName: appIcon(for: window.title))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isActive ? Color.primary.opacity(0.82) : Color.secondary)

                Text(window.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isActive ? Color.primary.opacity(0.88) : Color.secondary)
                    .lineLimit(1)
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            chromeTrafficButton(
                symbol: "xmark",
                color: Color(red: 1.00, green: 0.37, blue: 0.34),
                accessibilityLabel: "Close \(window.title)"
            ) {
                desktop.close(window.id)
            }

            chromeTrafficButton(
                symbol: "minus",
                color: Color(red: 1.00, green: 0.74, blue: 0.18),
                accessibilityLabel: "Minimize \(window.title)"
            ) {
                desktop.minimize(window.id)
            }

            chromeTrafficButton(
                symbol: window.isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                color: Color(red: 0.15, green: 0.79, blue: 0.25),
                accessibilityLabel: window.isMaximized ? "Restore \(window.title)" : "Full Screen \(window.title)"
            ) {
                desktop.toggleMaximize(window.id)
            }
        }
        .frame(width: 64, alignment: .leading)
    }

    private func chromeTrafficButton(
        symbol: String,
        color: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? color : Color.primary.opacity(0.16))
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(isActive ? 0.16 : 0.08), lineWidth: 0.6)
                    }

                Image(systemName: symbol)
                    .font(.system(size: 6.6, weight: .black))
                    .foregroundStyle(Color.black.opacity(isActive ? 0.50 : 0.0))
            }
            .frame(width: 20, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var windowCornerRadius: CGFloat {
        window.isMaximized ? 0 : 14
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
        case "Browser": return "safari.fill"
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Documents": return "doc.text.fill"
        case "Sheets": return "tablecells.fill"
        case "Notes": return "note.text"
        case "Files": return "folder.fill"
        case "Photos": return "photo.on.rectangle.angled"
        case "Settings": return "gearshape.fill"
        case "Calculator": return "plus.forwardslash.minus"
        case "Clipboard": return "doc.on.clipboard.fill"
        default: return "app.fill"
        }
    }
}

/// External displays are noninteractive, so resize input continues to be owned by
/// the iPhone trackpad. These eight lightweight markers make that existing all-edge
/// resize model visible and highlight the exact edge/corner currently targeted by
/// the shared DesktopSession cursor. There is no timer/display-link work here.
private struct DesktopResizeAffordances: View {
    let activeEdge: DesktopSession.ResizeEdge?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let horizontalLength = min(max(width * 0.18, 34), 82)
            let verticalLength = min(max(height * 0.18, 28), 70)

            ZStack {
                edge(.top, width: horizontalLength, height: 3)
                    .position(x: width / 2, y: 2)
                edge(.bottom, width: horizontalLength, height: 3)
                    .position(x: width / 2, y: height - 2)
                edge(.left, width: 3, height: verticalLength)
                    .position(x: 2, y: height / 2)
                edge(.right, width: 3, height: verticalLength)
                    .position(x: width - 2, y: height / 2)

                corner(.topLeft)
                    .position(x: 7, y: 7)
                corner(.topRight)
                    .position(x: width - 7, y: 7)
                corner(.bottomLeft)
                    .position(x: 7, y: height - 7)
                corner(.bottomRight)
                    .position(x: width - 7, y: height - 7)
            }
        }
    }

    private func edge(_ edge: DesktopSession.ResizeEdge, width: CGFloat, height: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(Color.primary.opacity(opacity(for: edge)))
            .frame(width: width, height: height)
    }

    private func corner(_ edge: DesktopSession.ResizeEdge) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(Color.primary.opacity(opacity(for: edge)), lineWidth: isActive(edge) ? 2.4 : 1.2)
            .frame(width: 12, height: 12)
    }

    private func isActive(_ edge: DesktopSession.ResizeEdge) -> Bool {
        activeEdge == edge
    }

    private func opacity(for edge: DesktopSession.ResizeEdge) -> Double {
        isActive(edge) ? 0.78 : 0.18
    }
}
