import SwiftUI
import WebKit

/// Full-featured desktop browser container with tabs and URL navigation.
struct DesktopBrowserView: View {
    @StateObject private var state = DesktopBrowserState.shared
    var onContinueOnPhone: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar
                .frame(height: 32)
                .background(Color(red: 0.12, green: 0.13, blue: 0.18))

            // Navigation Address Bar
            navigationBar
                .frame(height: 40)
                .background(Color(red: 0.15, green: 0.16, blue: 0.22))

            // Web Content Area
            WKWebViewRepresentable(url: state.activeTab?.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(state.tabs) { tab in
                        HStack(spacing: 6) {
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(tab.id == state.activeTabID ? .white : .white.opacity(0.6))
                                .lineLimit(1)
                                .frame(maxWidth: 120, alignment: .leading)

                            Button {
                                state.closeTab(id: tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            tab.id == state.activeTabID ? Color(red: 0.18, green: 0.20, blue: 0.28) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .onTapGesture {
                            state.activeTabID = tab.id
                            state.urlInput = tab.url?.absoluteString ?? ""
                        }
                    }
                }
                .padding(.horizontal, 6)
            }

            Button {
                state.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            Button {
                // Back action
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Button {
                // Forward action
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Button {
                // Reload action
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            // Address bar
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("Search or enter website name", text: $state.urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white)
                    .onSubmit {
                        if let valid = DesktopBrowserState.normalizeURL(state.urlInput) {
                            if let idx = state.tabs.firstIndex(where: { $0.id == state.activeTabID }) {
                                state.tabs[idx].url = valid
                                state.tabs[idx].title = valid.host ?? "Web"
                            }
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35), in: Capsule())

            if let onContinueOnPhone {
                Button(action: onContinueOnPhone) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue on iPhone")
            }
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Reusable WebKit Representable
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url, uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
