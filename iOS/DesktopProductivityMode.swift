import SwiftUI
import UIKit
import WebKit

@MainActor
final class DesktopNotesStore: ObservableObject {
    static let shared = DesktopNotesStore()

    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: "kamihi.desktop.notes") }
    }

    private init() {
        text = UserDefaults.standard.string(forKey: "kamihi.desktop.notes") ?? ""
    }
}

@MainActor
private final class DesktopWebBridge {
    static let shared = DesktopWebBridge()

    private final class WeakWebView {
        weak var value: WKWebView?
        init(_ value: WKWebView) { self.value = value }
    }

    private var webViews: [UUID: WeakWebView] = [:]

    func register(_ webView: WKWebView, for id: UUID) {
        webViews[id] = WeakWebView(webView)
    }

    func click(windowID: UUID, x: CGFloat, y: CGFloat) {
        guard let webView = webViews[windowID]?.value else { return }
        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const el = document.elementFromPoint(x, y);
          if (!el) return false;
          if (el.focus) el.focus();
          if (el.click) el.click();
          return true;
        })();
        """
        webView.evaluateJavaScript(script)
    }

    func contextClick(windowID: UUID, x: CGFloat, y: CGFloat) {
        guard let webView = webViews[windowID]?.value else { return }
        let safeX = min(max(x, 0), 1)
        let safeY = min(max(y, 0), 1)
        let script = """
        (() => {
          const x = window.innerWidth * \(safeX);
          const y = window.innerHeight * \(safeY);
          const el = document.elementFromPoint(x, y);
          if (!el) return false;
          el.dispatchEvent(new MouseEvent('contextmenu', {bubbles:true, clientX:x, clientY:y}));
          return true;
        })();
        """
        webView.evaluateJavaScript(script)
    }

    func scroll(windowID: UUID, deltaY: CGFloat) {
        guard let webView = webViews[windowID]?.value else { return }
        var offset = webView.scrollView.contentOffset
        offset.y += deltaY
        let maxY = max(0, webView.scrollView.contentSize.height - webView.scrollView.bounds.height)
        offset.y = min(max(offset.y, 0), maxY)
        webView.scrollView.setContentOffset(offset, animated: false)
    }

    func type(windowID: UUID, text: String) {
        guard let webView = webViews[windowID]?.value,
              let data = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = """
        (() => {
          const text = \(json);
          const el = document.activeElement;
          if (!el) return false;
          if (el.isContentEditable) {
            document.execCommand('insertText', false, text);
            return true;
          }
          if ('value' in el) {
            const start = el.selectionStart ?? el.value.length;
            const end = el.selectionEnd ?? start;
            if (el.setRangeText) el.setRangeText(text, start, end, 'end');
            else el.value += text;
            el.dispatchEvent(new Event('input', {bubbles:true}));
            el.dispatchEvent(new Event('change', {bubbles:true}));
            return true;
          }
          return false;
        })();
        """
        webView.evaluateJavaScript(script)
    }

    func pressEnter(windowID: UUID) {
        guard let webView = webViews[windowID]?.value else { return }
        let script = """
        (() => {
          const el = document.activeElement;
          if (!el) return false;
          const options = {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true};
          el.dispatchEvent(new KeyboardEvent('keydown', options));
          el.dispatchEvent(new KeyboardEvent('keypress', options));
          el.dispatchEvent(new KeyboardEvent('keyup', options));
          if (el.form && el.form.requestSubmit) el.form.requestSubmit();
          return true;
        })();
        """
        webView.evaluateJavaScript(script)
    }
}

@MainActor
extension DesktopSession {
    private func existingWindow(named title: String) -> DesktopWindow? {
        windows.first(where: { $0.title == title })
    }

    @discardableResult
    func openProductivityApp(_ title: String, frame: CGRect? = nil) -> UUID {
        if let existing = existingWindow(named: title) {
            restoreAndActivate(existing.id)
            if let frame, let index = windows.firstIndex(where: { $0.id == existing.id }) {
                windows[index].normalizedFrame = frame
                windows[index].isMaximized = false
            }
            return existing.id
        }

        let defaultFrame = frame ?? CGRect(x: 0.12, y: 0.10, width: 0.72, height: 0.72)
        let window = DesktopWindow(title: title, normalizedFrame: defaultFrame)
        windows.append(window)
        activeWindowID = window.id
        return window.id
    }

    func openChatGPT() { _ = openProductivityApp("ChatGPT") }
    func openYouTube() { _ = openProductivityApp("YouTube") }
    func openNotes() { _ = openProductivityApp("Notes") }

    func openVibeWorkspace() {
        let left = CGRect(x: 0.012, y: 0.055, width: 0.565, height: 0.835)
        let rightTop = CGRect(x: 0.588, y: 0.055, width: 0.400, height: 0.490)
        let rightBottom = CGRect(x: 0.588, y: 0.557, width: 0.400, height: 0.333)

        _ = openProductivityApp("ChatGPT", frame: left)
        _ = openProductivityApp("YouTube", frame: rightTop)
        _ = openProductivityApp("Notes", frame: rightBottom)
    }

    func snapActiveLeft() {
        guard let id = activeWindowID, let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMaximized = false
        windows[index].normalizedFrame = CGRect(x: 0.012, y: 0.055, width: 0.482, height: 0.835)
    }

    func snapActiveRight() {
        guard let id = activeWindowID, let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMaximized = false
        windows[index].normalizedFrame = CGRect(x: 0.506, y: 0.055, width: 0.482, height: 0.835)
    }

    func clickWebContentAtCursor() {
        guard let window = topProductivityWindow(at: cursor) else { return }
        activate(window.id)
        guard window.title != "Notes" else { return }
        let frame = effectiveFrame(for: window)
        let x = (cursor.x - frame.minX) / frame.width
        let totalY = (cursor.y - frame.minY) / frame.height
        let titleBarFraction: CGFloat = 0.075
        guard totalY > titleBarFraction else { return }
        let y = (totalY - titleBarFraction) / (1 - titleBarFraction)
        DesktopWebBridge.shared.click(windowID: window.id, x: x, y: y)
    }

    func contextClickAtCursor() {
        guard let window = topProductivityWindow(at: cursor), window.title != "Notes" else { return }
        activate(window.id)
        let frame = effectiveFrame(for: window)
        let x = (cursor.x - frame.minX) / frame.width
        let totalY = (cursor.y - frame.minY) / frame.height
        let titleBarFraction: CGFloat = 0.075
        guard totalY > titleBarFraction else { return }
        let y = (totalY - titleBarFraction) / (1 - titleBarFraction)
        DesktopWebBridge.shared.contextClick(windowID: window.id, x: x, y: y)
    }

    func scrollActiveWebView(deltaY: CGFloat) {
        guard let id = activeWindowID else { return }
        DesktopWebBridge.shared.scroll(windowID: id, deltaY: deltaY)
    }

    func typeIntoActiveWebView(_ text: String) {
        guard let id = activeWindowID else { return }
        DesktopWebBridge.shared.type(windowID: id, text: text)
    }

    func pressEnterInActiveWebView() {
        guard let id = activeWindowID else { return }
        DesktopWebBridge.shared.pressEnter(windowID: id)
    }

    private func topProductivityWindow(at point: CGPoint) -> DesktopWindow? {
        windows.reversed().first(where: { !$0.isMinimized && effectiveFrame(for: $0).contains(point) })
    }
}

final class ProductivityExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else { return }

        let controller = UIHostingController(
            rootView: ProductivityDesktopView()
                .environmentObject(DesktopSession.shared)
        )
        controller.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        Task { @MainActor in
            DesktopSession.shared.externalDisplayDidConnect()
            if DesktopSession.shared.windows.count <= 1 {
                DesktopSession.shared.openVibeWorkspace()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task { @MainActor in DesktopSession.shared.externalDisplayDidDisconnect() }
        window = nil
    }
}

struct ProductivityDesktopAwareRootView: View {
    @EnvironmentObject private var desktop: DesktopSession

    var body: some View {
        Group {
            if desktop.isExternalDisplayConnected {
                ProductivityPhoneControllerView()
            } else {
                KamihiAppShell()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: desktop.isExternalDisplayConnected)
    }
}

private final class ProductivityTrackpadUIView: UIView {
    var onBegin: (() -> Void)?
    var onMove: ((CGSize) -> Void)?
    var onScroll: ((CGFloat) -> Void)?
    var onTap: (() -> Void)?
    var onSecondaryTap: (() -> Void)?
    var onEnd: (() -> Void)?

    private var previousCentroid = CGPoint.zero
    private var totalDistance: CGFloat = 0
    private var maximumTouchCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func centroid(_ touches: Set<UITouch>) -> CGPoint {
        guard !touches.isEmpty else { return .zero }
        let points = touches.map { $0.location(in: self) }
        return CGPoint(x: points.map(\.x).reduce(0,+) / CGFloat(points.count), y: points.map(\.y).reduce(0,+) / CGFloat(points.count))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let all = event?.allTouches else { return }
        maximumTouchCount = max(maximumTouchCount, all.count)
        previousCentroid = centroid(all)
        totalDistance = 0
        if all.count == 1 { onBegin?() }
        if all.count >= 2 { onEnd?() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let all = event?.allTouches, !all.isEmpty else { return }
        maximumTouchCount = max(maximumTouchCount, all.count)
        let current = centroid(all)
        let delta = CGSize(width: current.x - previousCentroid.x, height: current.y - previousCentroid.y)
        totalDistance += hypot(delta.width, delta.height)
        previousCentroid = current

        if all.count >= 2 {
            onScroll?(delta.height * 2.2)
        } else {
            onMove?(delta)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let remaining = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
        if remaining.isEmpty {
            if totalDistance < 8 {
                if maximumTouchCount >= 2 { onSecondaryTap?() }
                else { onTap?() }
            }
            onEnd?()
            maximumTouchCount = 0
            totalDistance = 0
        } else {
            previousCentroid = centroid(Set(remaining))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onEnd?()
        maximumTouchCount = 0
        totalDistance = 0
    }
}

private struct ProductivityTrackpadSurface: UIViewRepresentable {
    @EnvironmentObject private var desktop: DesktopSession

    func makeUIView(context: Context) -> ProductivityTrackpadUIView {
        let view = ProductivityTrackpadUIView()
        view.onBegin = { desktop.beginPrimaryDrag() }
        view.onMove = { desktop.updatePrimaryDrag(delta: $0) }
        view.onScroll = { desktop.scrollActiveWebView(deltaY: $0) }
        view.onTap = {
            desktop.primaryClick()
            desktop.clickWebContentAtCursor()
        }
        view.onSecondaryTap = { desktop.contextClickAtCursor() }
        view.onEnd = { desktop.endPrimaryDrag() }
        return view
    }

    func updateUIView(_ uiView: ProductivityTrackpadUIView, context: Context) {}
}

struct ProductivityPhoneControllerView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var notes = DesktopNotesStore.shared
    @State private var typingBuffer = ""
    @State private var showingNotesEditor = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "display")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Kamihi Desktop").font(.headline)
                    Text("Desktop controller").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Vibe") { desktop.openVibeWorkspace() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                quickButton("ChatGPT", "sparkles") { desktop.openChatGPT() }
                quickButton("YouTube", "play.rectangle.fill") { desktop.openYouTube() }
                quickButton("Notes", "note.text") {
                    desktop.openNotes()
                    showingNotesEditor = true
                }
                quickButton("Split", "rectangle.split.2x1") { desktop.snapActiveRight() }
            }
            .padding(.horizontal, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.055))
                VStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill").font(.title2).foregroundStyle(.secondary)
                    Text("1 finger: pointer • 2 fingers: scroll").font(.caption).foregroundStyle(.secondary)
                }
                ProductivityTrackpadSurface().environmentObject(desktop)
            }
            .accessibilityLabel("Desktop trackpad")
            .accessibilityHint("One finger moves and clicks. Two fingers scroll or right click.")

            HStack(spacing: 8) {
                Button { desktop.snapActiveLeft() } label: { Image(systemName: "rectangle.lefthalf.inset.filled") }
                Button { desktop.snapActiveRight() } label: { Image(systemName: "rectangle.righthalf.inset.filled") }
                TextField("Type into active web app", text: $typingBuffer)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendTypingBuffer(pressEnter: true) }
                Button("Type") { sendTypingBuffer(pressEnter: false) }
                    .buttonStyle(.bordered)
                Button { desktop.pressEnterInActiveWebView() } label: { Image(systemName: "return") }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingNotesEditor) {
            NavigationStack {
                TextEditor(text: $notes.text)
                    .padding()
                    .navigationTitle("Desktop Notes")
                    .toolbar { Button("Done") { showingNotesEditor = false } }
            }
        }
    }

    private func quickButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
    }

    private func sendTypingBuffer(pressEnter: Bool) {
        guard !typingBuffer.isEmpty else {
            if pressEnter { desktop.pressEnterInActiveWebView() }
            return
        }
        desktop.typeIntoActiveWebView(typingBuffer)
        typingBuffer = ""
        if pressEnter { desktop.pressEnterInActiveWebView() }
    }
}

struct ProductivityDesktopView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var conserveEnergy: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.035, blue: 0.055), Color(red: 0.015, green: 0.018, blue: 0.028)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ForEach(desktop.windows) { window in
                    if !window.isMinimized {
                        ProductivityWindowView(window: window, canvasSize: proxy.size, animationsEnabled: !reduceMotion && !conserveEnergy)
                            .zIndex(window.id == desktop.activeWindowID ? 100 : Double(desktop.windows.firstIndex(of: window) ?? 0))
                    }
                }

                productivityTaskbar

                Image(systemName: "arrow.up.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 3)
                    .position(x: desktop.cursor.x * proxy.size.width, y: desktop.cursor.y * proxy.size.height)
                    .allowsHitTesting(false)
                    .zIndex(1000)
            }
        }
        .background(.black)
    }

    private var productivityTaskbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                taskbarButton("ChatGPT", "sparkles") { desktop.openChatGPT() }
                taskbarButton("YouTube", "play.rectangle.fill") { desktop.openYouTube() }
                taskbarButton("Notes", "note.text") { desktop.openNotes() }
                taskbarButton("Web", "safari") { desktop.openBrowser() }
                taskbarButton("Vibe", "rectangle.3.group") { desktop.openVibeWorkspace() }

                Spacer()

                if conserveEnergy {
                    Label("Power saver", systemImage: "leaf.fill").font(.caption)
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(context.date, style: .time).monospacedDigit().font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(Color.black.opacity(0.88))
            .overlay(alignment: .top) { Divider().opacity(0.35) }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .zIndex(900)
    }

    private func taskbarButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                Text(title).font(.system(size: 9))
            }
            .frame(width: 52, height: 38)
        }
        .buttonStyle(.plain)
    }
}

private struct ProductivityWindowView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var notes = DesktopNotesStore.shared

    let window: DesktopSession.DesktopWindow
    let canvasSize: CGSize
    let animationsEnabled: Bool

    var body: some View {
        let frame = desktop.effectiveFrame(for: window)

        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: iconForWindow).foregroundStyle(.secondary)
                Text(window.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Button { desktop.minimize(window.id) } label: { Image(systemName: "minus") }
                Button { desktop.toggleMaximize(window.id) } label: { Image(systemName: "square") }
                Button { desktop.close(window.id) } label: { Image(systemName: "xmark") }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.black.opacity(0.82))

            content
        }
        .frame(width: frame.width * canvasSize.width, height: frame.height * canvasSize.height)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(window.id == desktop.activeWindowID ? .white.opacity(0.28) : .white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.42), radius: 18, y: 8)
        .position(x: frame.midX * canvasSize.width, y: frame.midY * canvasSize.height)
        .animation(animationsEnabled ? .snappy(duration: 0.22) : nil, value: frame)
    }

    @ViewBuilder
    private var content: some View {
        switch window.title {
        case "ChatGPT":
            ProductivityWebView(windowID: window.id, url: URL(string: "https://chatgpt.com")!)
        case "YouTube":
            ProductivityWebView(windowID: window.id, url: URL(string: "https://www.youtube.com")!)
        case "Browser":
            ProductivityWebView(windowID: window.id, url: URL(string: "https://www.google.com")!)
        case "Notes":
            ScrollView {
                Text(notes.text.isEmpty ? "Your notes will appear here. Edit them from the iPhone controller." : notes.text)
                    .font(.system(size: 16))
                    .foregroundStyle(notes.text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
            }
            .background(Color(uiColor: .systemBackground))
        default:
            ZStack { Color.black.opacity(0.2); Text(window.title).foregroundStyle(.secondary) }
        }
    }

    private var iconForWindow: String {
        switch window.title {
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Notes": return "note.text"
        default: return "safari"
        }
    }
}

private struct ProductivityWebView: UIViewRepresentable {
    let windowID: UUID
    let url: URL

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var loadedURL: URL?

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let target = navigationAction.request.url { webView.load(URLRequest(url: target)) }
            return nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        DesktopWebBridge.shared.register(webView, for: windowID)
        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        DesktopWebBridge.shared.register(webView, for: windowID)
        if context.coordinator.loadedURL != url {
            webView.load(URLRequest(url: url))
            context.coordinator.loadedURL = url
        }
    }
}
