import SwiftUI
import WebKit

/// Dedicated application container for ChatGPT on Kamihi Desktop.
struct DesktopChatGPTView: View {
    var onContinueOnPhone: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // App Bar
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.72, blue: 0.62))

                Text("ChatGPT")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if let onContinueOnPhone {
                    Button(action: onContinueOnPhone) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone.and.arrow.forward")
                            Text("Continue on iPhone")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.12, green: 0.13, blue: 0.17))

            // Web Content
            WKWebViewRepresentable(
                url: URL(string: "https://chatgpt.com"),
                registryKey: "ChatGPT"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
