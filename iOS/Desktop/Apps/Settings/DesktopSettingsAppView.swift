import SwiftUI
import UIKit
import WebKit

/// A real desktop Settings application. The external display scene is
/// non-interactive on iPhone, so this view intentionally uses the same retained
/// WebKit input registry as Browser/ChatGPT/YouTube. The iPhone trackpad can click
/// and scroll every control while changes are applied to the existing native
/// settings stores immediately.
struct DesktopSettingsAppView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var features = DesktopFeatureState.shared
    @ObservedObject private var appearance = DesktopAppearanceSettings.shared
    @ObservedObject private var glass = DesktopGlassAppearance.shared
    @ObservedObject private var trackpad = TrackpadSettings.shared
    @ObservedObject private var display = ExternalDisplayCoordinator.shared
    @ObservedObject private var wallpaper = DesktopWallpaperManager.shared
    @ObservedObject private var browser = DesktopBrowserState.shared
    @ObservedObject private var importer = DesktopSafariImportPresenter.shared
    @AppStorage("kamihi.desktop.showWidgets") private var showWidgets = true

    var body: some View {
        DesktopSettingsWebView(snapshot: snapshot, desktop: desktop)
            .background(Color.clear)
    }

    private var snapshot: DesktopSettingsSnapshot {
        DesktopSettingsSnapshot(
            theme: appearance.colorTheme,
            glassStyle: glass.style,
            glassHighlights: glass.highlightsEnabled,
            wallpaperID: wallpaper.selectedWallpaperID,
            showWidgets: showWidgets,
            pointerSensitivity: trackpad.pointerSensitivity,
            pointerAcceleration: trackpad.pointerAcceleration,
            scrollSpeed: trackpad.scrollSpeed,
            naturalScrolling: trackpad.naturalScrolling,
            scrollMomentum: trackpad.scrollMomentum,
            tapToClick: trackpad.tapToClick,
            dragLock: trackpad.dragLock,
            haptics: trackpad.hapticsEnabled,
            cursorStyle: trackpad.cursorStyle,
            uiScale: features.uiScale,
            animationIntensity: features.animationIntensity,
            batterySaver: features.batterySaverOverride,
            workspace: features.workspace,
            preferredRefreshRate: display.preferredRefreshRate,
            connected: display.isConnected,
            capabilitySummary: display.capabilitySummary,
            calibrationSummary: display.calibrationSummary,
            horizontalSafeMargin: display.horizontalSafeMargin,
            verticalSafeMargin: display.verticalSafeMargin,
            availableModes: display.availableDisplayModes.map { .init(id: $0.id, title: $0.title, current: $0.isCurrent) },
            wallpaperOptions: wallpaper.wallpapers.map { .init(id: $0.id, title: $0.name) },
            bookmarkCount: browser.bookmarks.count,
            historyCount: browser.history.count,
            importMessage: importer.lastMessage,
            importRevision: importer.revision
        )
    }
}

private struct DesktopSettingsSnapshot: Equatable {
    struct Option: Equatable { let id: String; let title: String; let current: Bool
        init(id: String, title: String, current: Bool = false) { self.id = id; self.title = title; self.current = current }
    }
    let theme: DesktopColorTheme
    let glassStyle: DesktopGlassStyle
    let glassHighlights: Bool
    let wallpaperID: String
    let showWidgets: Bool
    let pointerSensitivity: Double
    let pointerAcceleration: Double
    let scrollSpeed: Double
    let naturalScrolling: Bool
    let scrollMomentum: Bool
    let tapToClick: Bool
    let dragLock: Bool
    let haptics: Bool
    let cursorStyle: CursorStyle
    let uiScale: Double
    let animationIntensity: Double
    let batterySaver: Bool
    let workspace: DesktopFeatureState.Workspace
    let preferredRefreshRate: Int
    let connected: Bool
    let capabilitySummary: String
    let calibrationSummary: String
    let horizontalSafeMargin: Double
    let verticalSafeMargin: Double
    let availableModes: [Option]
    let wallpaperOptions: [Option]
    let bookmarkCount: Int
    let historyCount: Int
    let importMessage: String
    let importRevision: Int
}

private struct DesktopSettingsWebView: UIViewRepresentable {
    let snapshot: DesktopSettingsSnapshot
    let desktop: DesktopSession

    func makeCoordinator() -> Coordinator { Coordinator(desktop: desktop) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.userContentController.add(context.coordinator, name: "kamihiSettings")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.alwaysBounceVertical = true
        webView.customUserAgent = "KamihiDesktop/Settings"
        DesktopWebInputRegistry.shared.register(webView, key: "Settings")
        context.coordinator.render(snapshot, in: webView, force: true)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.desktop = desktop
        context.coordinator.render(snapshot, in: webView, force: false)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "kamihiSettings")
        DesktopWebInputRegistry.shared.unregister(webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var desktop: DesktopSession
        private var lastSnapshot: DesktopSettingsSnapshot?

        init(desktop: DesktopSession) { self.desktop = desktop }

        func render(_ snapshot: DesktopSettingsSnapshot, in webView: WKWebView, force: Bool) {
            guard force || snapshot != lastSnapshot else { return }
            lastSnapshot = snapshot
            webView.loadHTMLString(Self.html(snapshot), baseURL: URL(string: "https://settings.kamihi.local/"))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "kamihiSettings",
                  let payload = message.body as? [String: Any],
                  let action = payload["action"] as? String else { return }
            let value = payload["value"] as? String ?? ""
            perform(action: action, value: value)
        }

        private func perform(action: String, value: String) {
            let trackpad = TrackpadSettings.shared
            let features = DesktopFeatureState.shared
            let display = ExternalDisplayCoordinator.shared

            switch action {
            case "theme":
                if let theme = DesktopColorTheme(rawValue: value) { DesktopAppearanceSettings.shared.colorTheme = theme }
            case "glassStyle":
                if let style = DesktopGlassStyle(rawValue: value) { DesktopGlassAppearance.shared.style = style }
            case "glassHighlights": DesktopGlassAppearance.shared.highlightsEnabled.toggle()
            case "wallpaper": DesktopWallpaperManager.shared.selectWallpaper(id: value)
            case "widgets":
                let next = !(UserDefaults.standard.object(forKey: "kamihi.desktop.showWidgets") as? Bool ?? true)
                UserDefaults.standard.set(next, forKey: "kamihi.desktop.showWidgets")
            case "pointerProfile":
                if let profile = DesktopPointerProfile(rawValue: value) { trackpad.applyPointerProfile(profile) }
            case "pointerSpeed":
                trackpad.pointerSensitivity += value == "up" ? 0.10 : -0.10
            case "pointerAcceleration":
                trackpad.pointerAcceleration += value == "up" ? 0.10 : -0.10
            case "scrollSpeed":
                trackpad.scrollSpeed += value == "up" ? 0.10 : -0.10
            case "naturalScrolling": trackpad.naturalScrolling.toggle()
            case "scrollMomentum": trackpad.scrollMomentum.toggle()
            case "tapToClick": trackpad.tapToClick.toggle()
            case "dragLock": trackpad.dragLock.toggle()
            case "haptics": trackpad.hapticsEnabled.toggle()
            case "cursorStyle":
                if let style = CursorStyle(rawValue: value) { trackpad.cursorStyle = style }
            case "refresh":
                display.preferredRefreshRate = Int(value) ?? 120
            case "displayMode":
                if let option = display.availableDisplayModes.first(where: { $0.id == value }) { display.selectDisplayMode(option) }
            case "safeH":
                display.horizontalSafeMargin += value == "up" ? 0.005 : -0.005
            case "safeV":
                display.verticalSafeMargin += value == "up" ? 0.005 : -0.005
            case "resetCalibration":
                display.horizontalSafeMargin = 0; display.verticalSafeMargin = 0
                display.leftSafeTrim = 0; display.rightSafeTrim = 0
                display.topSafeTrim = 0; display.bottomSafeTrim = 0
            case "uiScale":
                features.uiScale = Double(value) ?? 1; features.persistPreferences()
            case "animation":
                features.animationIntensity = Double(value) ?? 1; features.persistPreferences()
            case "batterySaver":
                features.batterySaverOverride.toggle(); features.persistPreferences()
            case "workspace":
                if let workspace = DesktopFeatureState.Workspace(rawValue: value) { features.setWorkspace(workspace, desktop: desktop) }
            case "saveWorkspace": features.saveSession(desktop: desktop)
            case "restoreWorkspace": _ = features.restoreSession(desktop: desktop)
            case "minimizeAll": desktop.minimizeAllWindows()
            case "restoreAll": desktop.restoreAllWindows()
            case "clearHistory": DesktopBrowserState.shared.clearHistory()
            case "importSafari": DesktopSafariImportPresenter.shared.present()
            case "onboarding": DesktopOnboardingPhonePresenter.present()
            default: break
            }
            if trackpad.hapticsEnabled { Haptics.touchTap() }
        }

        private static func html(_ s: DesktopSettingsSnapshot) -> String {
            func selected(_ yes: Bool) -> String { yes ? " selected" : "" }
            func active(_ yes: Bool) -> String { yes ? " active" : "" }
            func esc(_ value: String) -> String {
                value.replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
            }
            func button(_ title: String, action: String, value: String, isActive: Bool = false) -> String {
                "<button class='pill\(active(isActive))' onclick=\"send('" + esc(action) + "','" + esc(value) + "')\">" + esc(title) + "</button>"
            }
            let themeButtons = DesktopColorTheme.allCases.map { button($0.title, action: "theme", value: $0.rawValue, isActive: s.theme == $0) }.joined()
            let glassButtons = DesktopGlassStyle.allCases.map { button($0.title, action: "glassStyle", value: $0.rawValue, isActive: s.glassStyle == $0) }.joined()
            let profileButtons = DesktopPointerProfile.allCases.map { button($0.title, action: "pointerProfile", value: $0.rawValue, isActive: TrackpadSettings.shared.matchingPointerProfile == $0) }.joined()
            let cursorButtons = CursorStyle.allCases.map { button($0.rawValue, action: "cursorStyle", value: $0.rawValue, isActive: s.cursorStyle == $0) }.joined()
            let workspaceButtons = DesktopFeatureState.Workspace.allCases.map { button($0.rawValue, action: "workspace", value: $0.rawValue, isActive: s.workspace == $0) }.joined()
            let wallpaperButtons = s.wallpaperOptions.map { button($0.title, action: "wallpaper", value: $0.id, isActive: s.wallpaperID == $0.id) }.joined()
            let modeButtons = s.availableModes.isEmpty ? "<div class='muted'>Connect RayNeo or a monitor to see hardware display modes.</div>" : s.availableModes.map { button($0.title, action: "displayMode", value: $0.id, isActive: $0.current) }.joined()

            return """
            <!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1,maximum-scale=1'>
            <style>
            :root{color-scheme:light dark;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif;--accent:#5ac8fa;--line:rgba(255,255,255,.16);--card:rgba(255,255,255,.075)}
            *{box-sizing:border-box}html,body{margin:0;min-height:100%;background:transparent;color:CanvasText}body{padding:22px;background:radial-gradient(circle at 90% 0%,rgba(90,200,250,.12),transparent 38%),radial-gradient(circle at 0% 95%,rgba(175,82,222,.10),transparent 34%)}
            .top{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px}.title{font-size:28px;font-weight:750;letter-spacing:-.5px}.sub{font-size:12px;opacity:.58}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.card{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:16px;backdrop-filter:blur(26px) saturate(145%);-webkit-backdrop-filter:blur(26px) saturate(145%);box-shadow:inset 0 1px rgba(255,255,255,.12),0 8px 28px rgba(0,0,0,.10)}.wide{grid-column:1/-1}.card h2{font-size:15px;margin:0 0 4px}.hint,.muted{font-size:11px;opacity:.58;line-height:1.4;margin-bottom:10px}.row{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:9px 0;border-top:1px solid rgba(127,127,127,.12)}.row:first-of-type{border-top:0}.label{font-size:12px;font-weight:650}.value{font-size:11px;opacity:.68}.pills{display:flex;flex-wrap:wrap;gap:7px;margin-top:8px}.pill{appearance:none;border:1px solid rgba(127,127,127,.24);background:rgba(127,127,127,.10);color:inherit;border-radius:999px;padding:8px 11px;font-size:11px;font-weight:650;min-height:32px}.pill.active{background:rgba(90,200,250,.20);border-color:rgba(90,200,250,.62);box-shadow:inset 0 1px rgba(255,255,255,.18)}.pill.danger{border-color:rgba(255,69,58,.42);color:#ff6961}.step{display:flex;gap:6px;align-items:center}.step button{width:34px;height:32px;border-radius:9px;border:1px solid rgba(127,127,127,.2);background:rgba(127,127,127,.1);color:inherit;font-size:16px}.status{display:inline-flex;gap:6px;align-items:center;padding:6px 9px;border-radius:999px;background:rgba(52,199,89,.12);font-size:11px;font-weight:650}.dot{width:7px;height:7px;border-radius:50%;background:#34c759}.off .dot{background:#ff9f0a}.off{background:rgba(255,159,10,.12)}@media(max-width:760px){.grid{grid-template-columns:1fr}.wide{grid-column:auto}}
            </style></head><body>
            <div class='top'><div><div class='title'>Settings</div><div class='sub'>Everything that shapes your Kamihi Desktop, in one place.</div></div><div class='status\(s.connected ? "" : " off")'><span class='dot'></span>\(s.connected ? "External display connected" : "Desktop Lab / waiting")</div></div>
            <div class='grid'>
              <section class='card'><h2>Appearance & Glass</h2><div class='hint'>One visual language across windows, dock, launcher and menu bar.</div><div class='label'>Theme</div><div class='pills'>\(themeButtons)</div><div class='label' style='margin-top:12px'>Glass depth</div><div class='pills'>\(glassButtons)\(button(s.glassHighlights ? "Highlights On" : "Highlights Off", action: "glassHighlights", value: "", isActive: s.glassHighlights))</div><div class='label' style='margin-top:12px'>Wallpaper</div><div class='pills'>\(wallpaperButtons)</div><div class='pills'>\(button(s.showWidgets ? "Widgets On" : "Widgets Off", action: "widgets", value: "", isActive: s.showWidgets))</div></section>
              <section class='card'><h2>RayNeo & Display</h2><div class='hint'>\(esc(s.capabilitySummary)) · \(esc(s.calibrationSummary))</div><div class='label'>Refresh preference</div><div class='pills'>\(button("60 Hz", action:"refresh", value:"60", isActive:s.preferredRefreshRate == 60))\(button("120 Hz", action:"refresh", value:"120", isActive:s.preferredRefreshRate == 120))</div><div class='label' style='margin-top:12px'>Hardware mode</div><div class='pills'>\(modeButtons)</div><div class='row'><div><div class='label'>Horizontal safe margin</div><div class='value'>\(Int((s.horizontalSafeMargin*100).rounded()))%</div></div><div class='step'><button onclick="send('safeH','down')">−</button><button onclick="send('safeH','up')">+</button></div></div><div class='row'><div><div class='label'>Vertical safe margin</div><div class='value'>\(Int((s.verticalSafeMargin*100).rounded()))%</div></div><div class='step'><button onclick="send('safeV','down')">−</button><button onclick="send('safeV','up')">+</button></div></div><div class='pills'>\(button("Reset calibration", action:"resetCalibration", value:""))</div></section>
              <section class='card'><h2>Pointer & Trackpad</h2><div class='hint'>Tune the phone controller without changing the one-desktop workflow.</div><div class='label'>Pointer profile</div><div class='pills'>\(profileButtons)</div><div class='row'><div><div class='label'>Pointer speed</div><div class='value'>\(String(format:"%.2fx",s.pointerSensitivity))</div></div><div class='step'><button onclick="send('pointerSpeed','down')">−</button><button onclick="send('pointerSpeed','up')">+</button></div></div><div class='row'><div><div class='label'>Acceleration</div><div class='value'>\(String(format:"%.1f",s.pointerAcceleration))</div></div><div class='step'><button onclick="send('pointerAcceleration','down')">−</button><button onclick="send('pointerAcceleration','up')">+</button></div></div><div class='row'><div><div class='label'>Scroll speed</div><div class='value'>\(String(format:"%.1fx",s.scrollSpeed))</div></div><div class='step'><button onclick="send('scrollSpeed','down')">−</button><button onclick="send('scrollSpeed','up')">+</button></div></div><div class='pills'>\(button(s.naturalScrolling ? "Natural Scroll On":"Natural Scroll Off",action:"naturalScrolling",value:"",isActive:s.naturalScrolling))\(button(s.scrollMomentum ? "Momentum On":"Momentum Off",action:"scrollMomentum",value:"",isActive:s.scrollMomentum))\(button(s.tapToClick ? "Tap to Click On":"Tap to Click Off",action:"tapToClick",value:"",isActive:s.tapToClick))\(button(s.dragLock ? "Drag Lock On":"Drag Lock Off",action:"dragLock",value:"",isActive:s.dragLock))\(button(s.haptics ? "Haptics On":"Haptics Off",action:"haptics",value:"",isActive:s.haptics))</div><div class='label' style='margin-top:12px'>Cursor</div><div class='pills'>\(cursorButtons)</div></section>
              <section class='card'><h2>Desktop Behavior</h2><div class='hint'>Workspace, scale, motion and power settings are persisted automatically.</div><div class='label'>Workspace</div><div class='pills'>\(workspaceButtons)</div><div class='label' style='margin-top:12px'>UI scale</div><div class='pills'>\([0.90,1.00,1.10,1.20].map{ button(String(format:"%.0f%%",$0*100),action:"uiScale",value:String($0),isActive:abs(s.uiScale-$0)<0.01)}.joined())</div><div class='label' style='margin-top:12px'>Motion</div><div class='pills'>\(button("Reduced",action:"animation",value:"0.35",isActive:s.animationIntensity<0.6))\(button("Standard",action:"animation",value:"1.0",isActive:s.animationIntensity>=0.6))\(button(s.batterySaver ? "Battery Saver On":"Battery Saver Off",action:"batterySaver",value:"",isActive:s.batterySaver))</div><div class='pills'>\(button("Save workspace",action:"saveWorkspace",value:""))\(button("Restore workspace",action:"restoreWorkspace",value:""))\(button("Minimize all",action:"minimizeAll",value:""))\(button("Restore all",action:"restoreAll",value:""))</div></section>
              <section class='card wide'><h2>Browser, Safari & Setup</h2><div class='hint'>\(s.bookmarkCount) bookmarks · \(s.historyCount) history items. Safari import opens the secure Files picker on your iPhone.</div><div class='row'><div><div class='label'>Safari bookmarks</div><div class='value'>\(esc(s.importMessage))</div></div><div class='pills'>\(button("Import from Safari",action:"importSafari",value:""))\(button("Clear history",action:"clearHistory",value:""))\(button("Run onboarding again",action:"onboarding",value:""))</div></div></section>
            </div>
            <script>function send(action,value){window.webkit.messageHandlers.kamihiSettings.postMessage({action:action,value:value||''});}</script>
            </body></html>
            """
        }
    }
}

@MainActor
private enum DesktopOnboardingPhonePresenter {
    static func present() {
        UserDefaults.standard.set(false, forKey: "hasCompletedDesktopOnboarding")
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
        guard let scene = scenes.first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let controller = UIHostingController(rootView: DesktopOnboardingSheet())
        controller.modalPresentationStyle = .pageSheet
        top.present(controller, animated: true)
    }
}
