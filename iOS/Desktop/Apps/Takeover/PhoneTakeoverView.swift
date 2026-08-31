import SwiftUI
import WebKit

/// "Continue on iPhone" takeover sheet.
/// Presents an interactive full-screen session on the phone for web logins,
/// Password AutoFill, passkeys, CAPTCHAs, and forms, then seamlessly returns to the desktop.
struct PhoneTakeoverView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var desktop: DesktopSession
    let windowID: UUID

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Informational banner
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.cyan)
                        Text("Interactive Phone Session • Password AutoFill & Touch Enabled")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.15))

                    // Live Web View
                    if let window = desktop.windows.first(where: { $0.id == windowID }) {
                        WKWebViewRepresentable(url: url(for: window.title))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Phone Takeover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Return to Desktop") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func url(for title: String) -> URL? {
        switch title {
        case "Browser":
            return DesktopBrowserState.shared.activeTab?.url ?? URL(string: "https://www.google.com")
        case "ChatGPT":
            return URL(string: "https://chatgpt.com")
        case "YouTube":
            return URL(string: "https://www.youtube.com")
        default:
            return URL(string: "https://www.google.com")
        }
    }
}
