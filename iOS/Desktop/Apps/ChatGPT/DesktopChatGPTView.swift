import SwiftUI
import WebKit

/// Dedicated ChatGPT application container. The web product stays intact while
/// its host chrome follows the same Golden Gate toolbar language as every app.
struct DesktopChatGPTView: View {
    var onContinueOnPhone: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.18, green: 0.70, blue: 0.60))
                    .frame(width: 26, height: 26)
                    .background(Color(red: 0.18, green: 0.70, blue: 0.60).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text("ChatGPT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.90))

                Spacer()

                if let onContinueOnPhone {
                    Button(action: onContinueOnPhone) {
                        DesktopToolbarIconLabel("iphone.and.arrow.forward")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue ChatGPT on iPhone")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: DesktopShellMetrics.compactToolbarHeight)
            .desktopAppToolbar()

            WKWebViewRepresentable(
                url: URL(string: "https://chatgpt.com"),
                registryKey: "ChatGPT"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesktopShellPalette.canvas)
    }
}
