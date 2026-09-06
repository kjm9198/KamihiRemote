import SwiftUI
import WebKit

/// Dedicated YouTube application container with the same compact desktop toolbar
/// and semantic materials used throughout Kamihi Desktop.
struct DesktopYouTubeView: View {
    var onContinueOnPhone: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.11), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text("YouTube")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.90))

                Spacer()

                if let onContinueOnPhone {
                    Button(action: onContinueOnPhone) {
                        DesktopToolbarIconLabel("iphone.and.arrow.forward")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue YouTube on iPhone")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: DesktopShellMetrics.compactToolbarHeight)
            .desktopAppToolbar()

            WKWebViewRepresentable(
                url: URL(string: "https://www.youtube.com"),
                registryKey: "YouTube"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesktopShellPalette.canvas)
    }
}
