import SwiftUI
import UIKit
import WebKit

@MainActor
final class DesktopSession: ObservableObject {
    static let shared = DesktopSession()

    struct DesktopWindow: Identifiable, Equatable {
        let id: UUID
        var title: String
        var normalizedFrame: CGRect
        var isMinimized: Bool
        var isMaximized: Bool

        init(
            id: UUID = UUID(),
            title: String,
            normalizedFrame: CGRect = CGRect(x: 0.17, y: 0.14, width: 0.66, height: 0.68),
            isMinimized: Bool = false,
            isMaximized: Bool = false
        ) {
            self.id = id
            self.title = title
            self.normalizedFrame = normalizedFrame
            self.isMinimized = isMinimized
            self.isMaximized = isMaximized
        }
    }

    @Published private(set) var isExternalDisplayConnected = false
    @Published var cursor = CGPoint(x: 0.5, y: 0.45)
    @Published var windows: [DesktopWindow] = []
    @Published var activeWindowID: UUID?

    private var dragWindowID: UUID?
    private var dragOffset = CGPoint.zero

    private init() {}

    func externalDisplayDidConnect() {
        isExternalDisplayConnected = true
        if windows.isEmpty {
            openBrowser()
        }
    }

    func externalDisplayDidDisconnect() {
        isExternalDisplayConnected = false
        dragWindowID = nil
    }

    func openBrowser() {
        if let existing = windows.first(where: { $0.title == "Browser" }) {
            restoreAndActivate(existing.id)
            return
        }

        let window = DesktopWindow(title: "Browser")
        windows.append(window)
        activeWindowID = window.id
    }

    func activate(_ id: UUID) {
        activeWindowID = id
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let window = windows.remove(at: index)
        windows.append(window)
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
        if activeWindowID == id {
            activeWindowID = windows.last?.id
        }
    }

    func minimize(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = true }
        activeWindowID = windows.last(where: { !$0.isMinimized && $0.id != id })?.id
    }

    func toggleMaximize(_ id: UUID) {
        mutateWindow(id) { window in
            window.isMaximized.toggle()
        }
        activate(id)
    }

    func restoreAndActivate(_ id: UUID) {
        mutateWindow(id) { $0.isMinimized = false }
        activate(id)
    }

    func movePointer(delta: CGSize, sensitivity: CGFloat = 1.35) {
        let dx = delta.width / 430 * sensitivity
        let dy = delta.height / 800 * sensitivity
        cursor.x = min(max(cursor.x + dx, 0.006), 0.994)
        cursor.y = min(max(cursor.y + dy, 0.006), 0.994)
    }

    func primaryClick() {
        if cursor.y > 0.91 {
            openBrowser()
            return
        }

        guard let id = topWindow(at: cursor) else { return }
        activate(id)
    }

    func beginPrimaryDrag() {
        guard let id = topWindow(at: cursor),
              let window = windows.first(where: { $0.id == id }),
              !window.isMaximized else { return }

        let titleBarHeight: CGFloat = 0.07
        guard cursor.y >= window.normalizedFrame.minY,
              cursor.y <= window.normalizedFrame.minY + titleBarHeight else { return }

        activate(id)
        dragWindowID = id
        dragOffset = CGPoint(
            x: cursor.x - window.normalizedFrame.minX,
            y: cursor.y - window.normalizedFrame.minY
        )
    }

    func updatePrimaryDrag(delta: CGSize) {
        movePointer(delta: delta)
        guard let id = dragWindowID else { return }

        mutateWindow(id) { window in
            let width = window.normalizedFrame.width
            let height = window.normalizedFrame.height
            let newX = min(max(cursor.x - dragOffset.x, 0), 1 - width)
            let newY = min(max(cursor.y - dragOffset.y, 0.035), 0.90 - height)
            window.normalizedFrame.origin = CGPoint(x: newX, y: newY)
        }
    }

    func endPrimaryDrag() {
        dragWindowID = nil
    }

    private func mutateWindow(_ id: UUID, _ update: (inout DesktopWindow) -> Void) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        update(&windows[index])
    }

    private func topWindow(at point: CGPoint) -> UUID? {
        windows.reversed().first(where: {
            !$0.isMinimized && effectiveFrame(for: $0).contains(point)
        })?.id
    }

    func effectiveFrame(for window: DesktopWindow) -> CGRect {
        if window.isMaximized {
            return CGRect(x: 0.015, y: 0.055, width: 0.97, height: 0.84)
        }
        return window.normalizedFrame
    }
}

final class KamihiApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let configuration = UISceneConfiguration(
                name: "Kamihi External Display",
                sessionRole: connectingSceneSession.role
            )
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
            return configuration
        }

        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        let root = KamihiDesktopView()
            .environmentObject(DesktopSession.shared)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            DesktopSession.shared.externalDisplayDidConnect()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task { @MainActor in
            DesktopSession.shared.externalDisplayDidDisconnect()
        }
        window = nil
    }
}

struct DesktopAwareRootView: View {
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        Group {
            if desktop.isExternalDisplayConnected {
                DesktopControllerView()
            } else {
                KamihiAppShell()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: desktop.isExternalDisplayConnected)
    }
}

struct DesktopControllerView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @State private var previousDragTranslation = CGSize.zero
    @State private var dragHasStarted = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kamihi Desktop")
                        .font(.headline)
                    Text("External display connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 9, height: 9)
            }
            .padding(.horizontal, 18)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("Trackpad")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let delta = CGSize(
                                    width: value.translation.width - previousDragTranslation.width,
                                    height: value.translation.height - previousDragTranslation.height
                                )

                                if !dragHasStarted && hypot(value.translation.width, value.translation.height) > 5 {
                                    desktop.beginPrimaryDrag()
                                    dragHasStarted = true
                                }

                                if dragHasStarted {
                                    desktop.updatePrimaryDrag(delta: delta)
                                } else {
                                    desktop.movePointer(delta: delta)
                                }
                                previousDragTranslation = value.translation
                            }
                            .onEnded { value in
                                let distance = hypot(value.translation.width, value.translation.height)
                                if distance < 7 {
                                    desktop.primaryClick()
                                }
                                desktop.endPrimaryDrag()
                                dragHasStarted = false
                                previousDragTranslation = .zero
                            }
                    )
                    .accessibilityLabel("Desktop trackpad")
                    .accessibilityHint("Move one finger to control the cursor. Tap to click.")
            }

            HStack(spacing: 12) {
                Button {
                    desktop.openBrowser()
                } label: {
                    Label("Browser", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    desktop.primaryClick()
                } label: {
                    Label("Click", systemImage: "cursorarrow.click.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct KamihiDesktopView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 0.035, green: 0.045, blue: 0.07), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                topBar

                ForEach(desktop.windows) { window in
                    if !window.isMinimized {
                        DesktopWindowView(window: window, canvasSize: proxy.size)
                            .zIndex(window.id == desktop.activeWindowID ? 100 : Double(desktop.windows.firstIndex(of: window) ?? 0))
                    }
                }

                dock

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(radius: 7)
                    .overlay(Circle().stroke(.black.opacity(0.65), lineWidth: 1))
                    .position(
                        x: desktop.cursor.x * proxy.size.width,
                        y: desktop.cursor.y * proxy.size.height
                    )
                    .allowsHitTesting(false)
                    .zIndex(1000)
                    .animation(reduceMotion ? nil : .linear(duration: 0.035), value: desktop.cursor)
            }
        }
        .background(.black)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                Text("Kamihi Desktop")
                    .fontWeight(.semibold)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date, style: .time)
                    .monospacedDigit()
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(.ultraThinMaterial)
        .zIndex(900)
    }

    private var dock: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                DesktopDockButton(title: "Browser", systemImage: "safari") {
                    desktop.openBrowser()
                }
                DesktopDockButton(title: "Files", systemImage: "folder") {}
                DesktopDockButton(title: "Notes", systemImage: "note.text") {}
                DesktopDockButton(title: "Settings", systemImage: "gearshape") {}
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .zIndex(800)
    }
}

private struct DesktopDockButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 46, height: 38)
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }
}

private struct DesktopWindowView: View {
    @EnvironmentObject private var desktop: DesktopSession
    let window: DesktopSession.DesktopWindow
    let canvasSize: CGSize

    var body: some View {
        let frame = desktop.effectiveFrame(for: window)

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { desktop.close(window.id) } label: {
                    Circle().fill(.red).frame(width: 12, height: 12)
                }
                Button { desktop.minimize(window.id) } label: {
                    Circle().fill(.yellow).frame(width: 12, height: 12)
                }
                Button { desktop.toggleMaximize(window.id) } label: {
                    Circle().fill(.green).frame(width: 12, height: 12)
                }
                Text(window.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(.thinMaterial)

            if window.title == "Browser" {
                DesktopBrowserView()
            } else {
                ZStack {
                    Color.black.opacity(0.28)
                    Text(window.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(
            width: frame.width * canvasSize.width,
            height: frame.height * canvasSize.height
        )
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(window.id == desktop.activeWindowID ? .white.opacity(0.22) : .white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .position(
            x: (frame.midX * canvasSize.width),
            y: (frame.midY * canvasSize.height)
        )
    }
}

private struct DesktopBrowserView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
