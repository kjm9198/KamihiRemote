import SwiftUI

/// macOS Sonoma/Sequoia style desktop widgets with ultra-thin glassmorphic styling.
public struct DesktopWidgetsView: View {
    @StateObject private var power = DesktopPowerMonitor.shared
    @StateObject private var display = ExternalDisplayCoordinator.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Widget 1: Clock & Time Zone
            clockWidget

            // Widget 2: Calendar Glance
            calendarWidget

            // Widget 3: Hardware & 120Hz ProMotion Monitor
            hardwareWidget
        }
        .padding(.trailing, 20)
        .padding(.top, 42)
    }

    private var clockWidget: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    Text("Current Time")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }

                Text(context.date, style: .time)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()

                Text(TimeZone.current.localizedName(for: .generic, locale: .current) ?? "Local Time")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 170, height: 95)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }

    private var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(Date().formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.red)
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }

            Text(Date().formatted(.dateTime.day()))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(Date().formatted(.dateTime.month(.wide)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary)
        }
        .padding(12)
        .frame(width: 170, height: 95)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var hardwareWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "display")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cyan)
                Text("Display & Power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(display.maximumFramesPerSecond >= 120 ? Color.cyan : Color.orange)
                    .frame(width: 7, height: 7)
                Text(display.maximumFramesPerSecond >= 120 ? "120 Hz ProMotion" : "\(display.maximumFramesPerSecond) Hz Standard")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(display.maximumFramesPerSecond >= 120 ? Color.cyan : Color.primary)
            }

            HStack(spacing: 6) {
                let isLow = power.batteryLevel >= 0 && power.batteryLevel < 0.20
                Image(systemName: isLow ? "battery.25" : "battery.100")
                    .font(.system(size: 11))
                    .foregroundStyle(isLow ? Color.red : Color.green)
                Text("Battery \(power.batteryPercentageText)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(12)
        .frame(width: 170, height: 85)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
