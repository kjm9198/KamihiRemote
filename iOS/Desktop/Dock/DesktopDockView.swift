import SwiftUI

/// Floating iPadOS-inspired dock on the external display.
/// Uses the shared semantic shell tokens so the dock follows System/Light/Dark,
/// Reduce Transparency, and minimum touch-target conventions consistently.
struct DesktopDockView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @StateObject private var power = DesktopPowerMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var onOpenLauncher: () -> Void

    /// Keep the dock centered on the apps that make Kamihi useful as an everyday
    /// computer. This is intentionally a small launch set rather than permanent
    /// desktop furniture; every other running app still appears after the divider.
    private let pinnedApps: [(title: String, icon: String, color: Color)] = [
        ("Browser", "globe", Color(red: 0.22, green: 0.58, blue: 0.94)),
        ("Documents", "doc.text.fill", Color(red: 0.38, green: 0.63, blue: 0.95)),
        ("Files", "folder.fill", Color(red: 0.42, green: 0.68, blue: 0.94)),
        ("Notes", "note.text", Color(red: 0.92, green: 0.74, blue: 0.24)),
        ("ChatGPT", "sparkles", Color(red: 0.18, green: 0.72, blue: 0.62)),
        ("YouTube", "play.rectangle.fill", Color(red: 0.94, green: 0.22, blue: 0.28))
    ]

    private var pinnedTitles: Set<String> {
        Set(pinnedApps.map(\.title))
    }

    /// Keep every running desktop app reachable even when it is not one of the
    /// default pinned apps. This makes the dock act like a real taskbar instead
    /// of allowing Calculator, Settings, Photos, PDFs, custom web apps, etc. to
    /// become invisible once another window covers them.
    private var unpinnedRunningTitles: [String] {
        var seen = Set<String>()
        return desktop.windows.compactMap { window in
            let title = window.title
            guard !pinnedTitles.contains(title), seen.insert(title).inserted else { return nil }
            return title
        }
    }

    var body: some View {
        HStack(spacing: DesktopShellMetrics.compactSpacing) {
            Button(action: onOpenLauncher) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: DesktopShellMetrics.compactIcon, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(
                        width: DesktopShellMetrics.minimumHitTarget,
                        height: DesktopShellMetrics.minimumHitTarget
                    )
                    .background(
                        DesktopShellPalette.elevatedCanvas.opacity(reduceTransparency ? 1 : 0.72),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open App Library")
            .accessibilityHint("Shows all Kamihi Desktop apps")

            Divider()
                .frame(height: 28)
                .accessibilityHidden(true)

            ForEach(pinnedApps, id: \.title) { app in
                dockAppTile(title: app.title, icon: app.icon, color: app.color)
            }

            if !unpinnedRunningTitles.isEmpty {
                Divider()
                    .frame(height: 28)
                    .accessibilityHidden(true)

                ForEach(unpinnedRunningTitles, id: \.self) { title in
                    dockAppTile(
                        title: title,
                        icon: symbolForRunningApp(title),
                        color: DesktopShellPalette.secondaryLabel
                    )
                }
            }

            Spacer(minLength: DesktopShellMetrics.standardSpacing)

            statusSurface
        }
        .padding(.horizontal, DesktopShellMetrics.standardSpacing)
        .padding(.vertical, 6)
        .desktopShellChrome(cornerRadius: 28)
        .shadow(
            color: Color.black.opacity(reduceTransparency ? 0 : (colorScheme == .dark ? 0.26 : 0.12)),
            radius: reduceTransparency ? 0 : 12,
            x: 0,
            y: reduceTransparency ? 0 : 6
        )
    }

    private var statusSurface: some View {
        HStack(spacing: 10) {
            Label {
                Text("External")
                    .font(.caption.weight(.semibold))
            } icon: {
                Image(systemName: "display")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            Divider()
                .frame(height: 18)
                .accessibilityHidden(true)

            HStack(spacing: 5) {
                Image(systemName: batterySymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(batteryTint)
                    .accessibilityHidden(true)

                Text(power.batteryPercentageText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("iPhone battery")
            .accessibilityValue(batteryAccessibilityValue)

            Divider()
                .frame(height: 18)
                .accessibilityHidden(true)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date, style: .time)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("Current time")
            }
        }
        .frame(minHeight: DesktopShellMetrics.minimumHitTarget)
        .padding(.horizontal, 10)
        .background(
            DesktopShellPalette.elevatedCanvas.opacity(reduceTransparency ? 1 : 0.50),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(DesktopShellPalette.separator.opacity(reduceTransparency ? 0.62 : 0.30), lineWidth: reduceTransparency ? 1 : 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var batterySymbol: String {
        switch power.batteryState {
        case .charging:
            return "battery.100percent.bolt"
        case .full:
            return "battery.100percent"
        case .unknown, .unplugged:
            guard power.batteryLevel >= 0 else { return "battery.0percent" }
            switch power.batteryLevel {
            case 0.76...: return "battery.100percent"
            case 0.51..<0.76: return "battery.75percent"
            case 0.26..<0.51: return "battery.50percent"
            case 0.11..<0.26: return "battery.25percent"
            default: return "battery.0percent"
            }
        @unknown default:
            return "battery.0percent"
        }
    }

    private var batteryTint: Color {
        if power.batteryState == .charging || power.batteryState == .full {
            return .green
        }
        if power.batteryLevel >= 0 && power.batteryLevel <= 0.20 {
            return .orange
        }
        return DesktopShellPalette.secondaryLabel
    }

    private var batteryAccessibilityValue: String {
        let state: String
        switch power.batteryState {
        case .charging: state = "charging"
        case .full: state = "fully charged"
        case .unplugged: state = "on battery"
        case .unknown: state = "state unknown"
        @unknown default: state = "state unknown"
        }
        return "\(power.batteryPercentageText), \(state)"
    }

    private func symbolForRunningApp(_ title: String) -> String {
        let normalized = title.lowercased()
        if normalized.contains("setting") { return "gearshape.fill" }
        if normalized.contains("calculator") { return "plus.forwardslash.minus" }
        if normalized.contains("photo") { return "photo.on.rectangle.angled" }
        if normalized.contains("document") { return "doc.text.fill" }
        if normalized.contains("sheet") { return "tablecells.fill" }
        if normalized.contains("pdf") { return "doc.richtext.fill" }
        if normalized.contains("clipboard") { return "doc.on.clipboard.fill" }
        if normalized.contains("browser") || normalized.contains("web") { return "globe" }
        return "app.fill"
    }

    private func dockAppTile(title: String, icon: String, color: Color) -> some View {
        let isRunning = desktop.windows.contains(where: { $0.title == title })
        let isMinimized = desktop.windows.first(where: { $0.title == title })?.isMinimized ?? false
        let isActive = desktop.activeWindow?.title == title

        return VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: DesktopShellMetrics.compactIcon, weight: .semibold))
                .foregroundStyle(color)
                .frame(
                    width: DesktopShellMetrics.minimumHitTarget,
                    height: DesktopShellMetrics.minimumHitTarget
                )
                .background(
                    isActive
                        ? DesktopShellPalette.elevatedCanvas
                        : DesktopShellPalette.secondaryCanvas.opacity(reduceTransparency ? 1 : 0.62),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    if isActive {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DesktopShellPalette.accent.opacity(0.36), lineWidth: 1)
                    }
                }

            Capsule()
                .fill(isRunning ? (isMinimized ? Color.orange : DesktopShellPalette.label) : Color.clear)
                .frame(width: isActive ? 10 : 5, height: 4)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isRunning, let window = desktop.windows.first(where: { $0.title == title }) {
                desktop.restoreAndActivate(window.id)
            } else {
                desktop.openProductivityApp(
                    title,
                    frame: CGRect(x: 0.20, y: 0.165, width: 0.60, height: 0.60)
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Active" : (isMinimized ? "Minimized" : (isRunning ? "Running" : "Not running")))
        .accessibilityHint("Opens or activates this app")
        .accessibilityAddTraits(.isButton)
    }
}