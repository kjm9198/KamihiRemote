import SwiftUI
import UIKit
import WebKit

/// Desktop System Settings. The external display scene is non-interactive on
/// iPhone, so the app intentionally stays in the retained WebKit input registry:
/// every control can still be driven by the phone trackpad while applying native
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
            glassClarity: glass.clarity,
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
            importRevision: importer.revision,
            autohideDock: desktop.autohideDock,
            hasCustomPhoto: wallpaper.customWallpaperImage != nil
        )
    }
}

private struct DesktopSettingsSnapshot: Equatable {
    struct Option: Equatable {
        let id: String
        let title: String
        let current: Bool
        init(id: String, title: String, current: Bool = false) {
            self.id = id
            self.title = title
            self.current = current
        }
    }

    let theme: DesktopColorTheme
    let glassStyle: DesktopGlassStyle
    let glassClarity: Double
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
    let autohideDock: Bool
    let hasCustomPhoto: Bool
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
        webView.scrollView.alwaysBounceVertical = false
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
            case "glassClarity":
                DesktopGlassAppearance.shared.clarity = Double(value) ?? DesktopGlassAppearance.shared.clarity
            case "glassHighlights":
                DesktopGlassAppearance.shared.highlightsEnabled.toggle()
            case "wallpaper":
                DesktopWallpaperManager.shared.selectWallpaper(id: value)
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
                display.horizontalSafeMargin = 0
                display.verticalSafeMargin = 0
                display.leftSafeTrim = 0
                display.rightSafeTrim = 0
                display.topSafeTrim = 0
                display.bottomSafeTrim = 0
            case "uiScale":
                features.uiScale = Double(value) ?? 1
                features.persistPreferences()
            case "animation":
                features.animationIntensity = Double(value) ?? 1
                features.persistPreferences()
            case "batterySaver":
                features.batterySaverOverride.toggle()
                features.persistPreferences()
            case "autohideDock":
                desktop.autohideDock.toggle()
            case "openWallpaper":
                desktop.showWallpaperPicker = true
            case "customWallpaper":
                DesktopWallpaperManager.shared.selectWallpaper(id: "custom")
            case "workspace":
                if let workspace = DesktopFeatureState.Workspace(rawValue: value) { features.setWorkspace(workspace, desktop: desktop) }
            case "saveWorkspace":
                features.saveSession(desktop: desktop)
                DesktopRecoveryCoordinator.shared.saveSnapshot(desktop: desktop, force: true)
            case "restoreWorkspace":
                if !DesktopRecoveryCoordinator.shared.restoreSnapshot(desktop: desktop) {
                    _ = features.restoreSession(desktop: desktop)
                }
            case "minimizeAll": desktop.minimizeAllWindows()
            case "restoreAll": desktop.restoreAllWindows()
            case "clearHistory": DesktopBrowserState.shared.clearHistory()
            case "importSafari": DesktopSafariImportPresenter.shared.present()
            case "onboarding": DesktopOnboardingPhonePresenter.present()
            case "passkeyTakeover":
                if let browserWindow = desktop.windows.first(where: { $0.title == "Browser" }) {
                    desktop.requestPhoneTakeover(for: browserWindow.id)
                }
            default: break
            }

            if trackpad.hapticsEnabled { Haptics.touchTap() }
        }

        private static func html(_ s: DesktopSettingsSnapshot) -> String {
            func active(_ yes: Bool) -> String { yes ? " active" : "" }
            func esc(_ value: String) -> String {
                value.replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
            }
            func button(_ title: String, action: String, value: String, isActive: Bool = false) -> String {
                "<button class='choice\(active(isActive))' onclick=\"send('" + esc(action) + "','" + esc(value) + "')\">" + esc(title) + "</button>"
            }

            let themeButtons = DesktopColorTheme.allCases.map { button($0.title, action: "theme", value: $0.rawValue, isActive: s.theme == $0) }.joined()
            let glassButtons = DesktopGlassStyle.allCases.map { button($0.title, action: "glassStyle", value: $0.rawValue, isActive: s.glassStyle == $0) }.joined()
            let profileButtons = DesktopPointerProfile.allCases.map { button($0.title, action: "pointerProfile", value: $0.rawValue, isActive: TrackpadSettings.shared.matchingPointerProfile == $0) }.joined()
            let cursorButtons = CursorStyle.allCases.map { button($0.rawValue, action: "cursorStyle", value: $0.rawValue, isActive: s.cursorStyle == $0) }.joined()
            let workspaceButtons = DesktopFeatureState.Workspace.allCases.map { button($0.rawValue, action: "workspace", value: $0.rawValue, isActive: s.workspace == $0) }.joined()
            let wallpaperButtons = s.wallpaperOptions.map { button($0.title, action: "wallpaper", value: $0.id, isActive: s.wallpaperID == $0.id) }.joined()
            let modeButtons = s.availableModes.isEmpty
                ? "<div class='empty'>Connect RayNeo or a monitor to see hardware display modes.</div>"
                : s.availableModes.map { button($0.title, action: "displayMode", value: $0.id, isActive: $0.current) }.joined()

            return """
            <!doctype html>
            <html>
            <head>
              <meta name='viewport' content='width=device-width,initial-scale=1,maximum-scale=1'>
              <style>
              :root{
                color-scheme:light dark;
                font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','SF Pro Display',sans-serif;
                --accent:#0a84ff;
                --separator:rgba(127,127,127,.20);
                --sidebar:rgba(128,128,128,.085);
                --row:rgba(128,128,128,.075);
                --selected:rgba(10,132,255,.18);
                --glass:rgba(255,255,255,.075);
              }
              *{box-sizing:border-box}
              html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;color:CanvasText}
              button,input{font:inherit}
              .shell{display:grid;grid-template-columns:218px minmax(0,1fr);width:100%;height:100%;background:rgba(127,127,127,.035)}
              .sidebar{height:100%;padding:14px 10px;background:var(--sidebar);backdrop-filter:blur(34px) saturate(145%);-webkit-backdrop-filter:blur(34px) saturate(145%);border-right:.5px solid var(--separator);overflow:auto}
              .sidebar-title{font-size:20px;font-weight:720;letter-spacing:-.35px;padding:4px 10px 12px}
              .search{display:flex;align-items:center;gap:7px;height:30px;margin:0 5px 12px;padding:0 9px;border-radius:8px;background:rgba(127,127,127,.12);font-size:11px;opacity:.74}
              .nav{display:flex;align-items:center;width:100%;height:34px;padding:0 9px;border:0;border-radius:8px;background:transparent;color:inherit;text-align:left;font-size:12px;font-weight:560;cursor:pointer}
              .nav:hover{background:rgba(127,127,127,.10)}
              .nav.selected{background:var(--selected);font-weight:650}
              .ico{display:grid;place-items:center;width:21px;height:21px;margin-right:8px;border-radius:6px;color:white;font-size:11px;font-weight:800}
              .blue{background:#0a84ff}.purple{background:#bf5af2}.green{background:#30d158}.orange{background:#ff9f0a}.pink{background:#ff375f}.gray{background:#8e8e93}.cyan{background:#64d2ff;color:#123}
              .main{height:100%;overflow:auto;scroll-behavior:smooth;background:radial-gradient(circle at 100% 0%,rgba(90,200,250,.08),transparent 34%)}
              .toolbar{position:sticky;top:0;z-index:5;display:flex;align-items:center;justify-content:space-between;height:48px;padding:0 22px;background:rgba(127,127,127,.055);backdrop-filter:blur(34px) saturate(150%);-webkit-backdrop-filter:blur(34px) saturate(150%);border-bottom:.5px solid var(--separator)}
              .toolbar strong{font-size:13px;font-weight:650}.status{display:flex;align-items:center;gap:6px;font-size:10.5px;opacity:.70}.dot{width:7px;height:7px;border-radius:99px;background:#30d158}.offline .dot{background:#ff9f0a}
              .content{max-width:780px;margin:0 auto;padding:28px 30px 46px}
              .section{scroll-margin-top:64px;margin-bottom:30px}
              h1{font-size:26px;line-height:1.08;letter-spacing:-.65px;margin:0 0 5px}h2{font-size:15px;margin:0 0 12px;padding-left:2px}.lead{font-size:12px;opacity:.58;margin-bottom:22px}
              .group{overflow:hidden;border:.5px solid rgba(127,127,127,.18);border-radius:13px;background:var(--glass);backdrop-filter:blur(24px) saturate(135%);-webkit-backdrop-filter:blur(24px) saturate(135%);box-shadow:0 8px 28px rgba(0,0,0,.06),inset 0 .5px rgba(255,255,255,.14)}
              .row{display:flex;align-items:center;justify-content:space-between;gap:18px;min-height:50px;padding:10px 14px;border-top:.5px solid var(--separator)}.row:first-child{border-top:0}.row.stack{display:block}.label{font-size:12px;font-weight:610}.detail{font-size:10.5px;opacity:.55;line-height:1.35;margin-top:2px}.value{font-size:11px;opacity:.62;white-space:nowrap}
              .choices{display:flex;flex-wrap:wrap;justify-content:flex-end;gap:6px}.stack .choices{justify-content:flex-start;margin-top:9px}
              .choice{appearance:none;border:.5px solid rgba(127,127,127,.25);background:rgba(127,127,127,.10);color:inherit;border-radius:8px;padding:6px 9px;min-height:28px;font-size:10.5px;font-weight:610;cursor:pointer}.choice:hover{background:rgba(127,127,127,.16)}.choice.active{background:var(--selected);border-color:rgba(10,132,255,.48);color:inherit}.choice.danger{color:#ff453a}
              .step{display:flex;align-items:center;gap:5px}.step button{width:30px;height:28px;border:.5px solid rgba(127,127,127,.24);border-radius:8px;background:rgba(127,127,127,.09);color:inherit;font-size:15px}
              .range{display:flex;align-items:center;gap:10px;min-width:260px}.range input{accent-color:var(--accent);width:190px}.range span{width:42px;text-align:right;font-size:10.5px;opacity:.65}
              .empty{font-size:10.5px;opacity:.55;padding:4px 0}
              @media(max-width:720px){.shell{grid-template-columns:180px minmax(0,1fr)}.content{padding:22px 18px}.range{min-width:210px}.range input{width:140px}}
              </style>
            </head>
            <body>
            <div class='shell'>
              <aside class='sidebar'>
                <div class='sidebar-title'>System Settings</div>
                <div class='search'>⌕ &nbsp;Search settings</div>
                <button class='nav selected' onclick="go('appearance',this)"><span class='ico purple'>◐</span>Appearance</button>
                <button class='nav' onclick="go('display',this)"><span class='ico blue'>▣</span>Displays</button>
                <button class='nav' onclick="go('trackpad',this)"><span class='ico gray'>⌁</span>Trackpad</button>
                <button class='nav' onclick="go('desktop',this)"><span class='ico green'>▤</span>Desktop & Dock</button>
                <button class='nav' onclick="go('browser',this)"><span class='ico cyan'>◉</span>Browser & Safari</button>
                <button class='nav' onclick="go('setup',this)"><span class='ico orange'>✦</span>General</button>
              </aside>

              <main class='main' id='main'>
                <div class='toolbar'>
                  <strong>System Settings</strong>
                  <div class='status\(s.connected ? "" : " offline")'><span class='dot'></span>\(s.connected ? "External display connected" : "Desktop ready")</div>
                </div>
                <div class='content'>
                  <section class='section' id='appearance'>
                    <h1>Appearance</h1>
                    <div class='lead'>Golden Gate-style Liquid Glass and the visual language shared by every Kamihi app.</div>
                    <h2>Appearance</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Theme</div><div class='detail'>Use the system appearance or keep Desktop light or dark.</div></div><div class='choices'>\(themeButtons)</div></div>
                      <div class='row'><div><div class='label'>Liquid Glass</div><div class='detail'>Choose the diffusion profile used by windows, toolbars, Dock and sidebars.</div></div><div class='choices'>\(glassButtons)</div></div>
                      <div class='row'><div><div class='label'>Glass clarity</div><div class='detail'>Move from more tinted and readable to clearer glass.</div></div><div class='range'><input type='range' min='0' max='1' value='\(s.glassClarity)' step='.05' onchange="send('glassClarity',this.value)"><span>\(Int((s.glassClarity*100).rounded()))%</span></div></div>
                      <div class='row'><div><div class='label'>Specular highlights</div><div class='detail'>Adds the bright edge that separates glass from content beneath it.</div></div><div class='choices'>\(button(s.glassHighlights ? "On" : "Off", action:"glassHighlights", value:"", isActive:s.glassHighlights))</div></div>
                      <div class='row stack'><div class='label'>Wallpaper</div><div class='detail'>Wallpaper is visible through clear areas and influences the desktop atmosphere.</div><div class='choices'>\(wallpaperButtons)\(s.hasCustomPhoto ? button("Custom Photo", action:"customWallpaper", value:"", isActive:s.wallpaperID == "custom") : "")\(button("Choose / Upload…", action:"openWallpaper", value:""))\(button(s.showWidgets ? "Widgets On" : "Widgets Off", action:"widgets", value:"", isActive:s.showWidgets))</div></div>
                    </div>
                  </section>

                  <section class='section' id='display'>
                    <h1>Displays</h1><div class='lead'>\(esc(s.capabilitySummary)) · \(esc(s.calibrationSummary))</div>
                    <h2>RayNeo & External Display</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Refresh preference</div><div class='detail'>Prefer the smoothest supported output when power and thermals allow it.</div></div><div class='choices'>\(button("60 Hz",action:"refresh",value:"60",isActive:s.preferredRefreshRate == 60))\(button("120 Hz",action:"refresh",value:"120",isActive:s.preferredRefreshRate == 120))</div></div>
                      <div class='row stack'><div class='label'>Hardware mode</div><div class='detail'>Available modes reported by the connected display.</div><div class='choices'>\(modeButtons)</div></div>
                      <div class='row'><div><div class='label'>Horizontal safe margin</div><div class='detail'>Keep content away from cropped left/right edges.</div></div><div class='step'><span class='value'>\(Int((s.horizontalSafeMargin*100).rounded()))%</span><button onclick="send('safeH','down')">−</button><button onclick="send('safeH','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Vertical safe margin</div><div class='detail'>Keep content away from cropped top/bottom edges.</div></div><div class='step'><span class='value'>\(Int((s.verticalSafeMargin*100).rounded()))%</span><button onclick="send('safeV','down')">−</button><button onclick="send('safeV','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Calibration</div><div class='detail'>Return all safe-area trims to their defaults.</div></div><div class='choices'>\(button("Reset",action:"resetCalibration",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='trackpad'>
                    <h1>Trackpad</h1><div class='lead'>The iPhone is the precision input surface for the whole desktop.</div>
                    <h2>Point & Click</h2>
                    <div class='group'>
                      <div class='row stack'><div class='label'>Pointer profile</div><div class='choices'>\(profileButtons)</div></div>
                      <div class='row'><div><div class='label'>Pointer speed</div><div class='detail'>How far the desktop pointer moves for the same finger travel.</div></div><div class='step'><span class='value'>\(String(format:"%.2fx",s.pointerSensitivity))</span><button onclick="send('pointerSpeed','down')">−</button><button onclick="send('pointerSpeed','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Acceleration</div></div><div class='step'><span class='value'>\(String(format:"%.1f",s.pointerAcceleration))</span><button onclick="send('pointerAcceleration','down')">−</button><button onclick="send('pointerAcceleration','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Scroll speed</div></div><div class='step'><span class='value'>\(String(format:"%.1fx",s.scrollSpeed))</span><button onclick="send('scrollSpeed','down')">−</button><button onclick="send('scrollSpeed','up')">+</button></div></div>
                      <div class='row stack'><div class='label'>Gestures</div><div class='choices'>\(button(s.naturalScrolling ? "Natural scrolling":"Reverse scrolling",action:"naturalScrolling",value:"",isActive:s.naturalScrolling))\(button(s.scrollMomentum ? "Momentum":"No momentum",action:"scrollMomentum",value:"",isActive:s.scrollMomentum))\(button(s.tapToClick ? "Tap to click":"Press to click",action:"tapToClick",value:"",isActive:s.tapToClick))\(button(s.dragLock ? "Drag lock":"No drag lock",action:"dragLock",value:"",isActive:s.dragLock))\(button(s.haptics ? "Haptics":"No haptics",action:"haptics",value:"",isActive:s.haptics))</div></div>
                      <div class='row stack'><div class='label'>Cursor style</div><div class='choices'>\(cursorButtons)</div></div>
                    </div>
                  </section>

                  <section class='section' id='desktop'>
                    <h1>Desktop & Dock</h1><div class='lead'>Window layout, dock behavior and persistent workspaces.</div>
                    <h2>Dock & Windows</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Automatically hide and show the Dock</div><div class='detail'>Keep the dock hidden until the pointer touches the bottom of the screen.</div></div><div class='choices'>\(button(s.autohideDock ? "On":"Off",action:"autohideDock",value:"",isActive:s.autohideDock))</div></div>
                      <div class='row stack'><div class='label'>Workspace</div><div class='choices'>\(workspaceButtons)</div></div>
                      <div class='row'><div><div class='label'>UI scale</div></div><div class='choices'>\([0.90,1.00,1.10,1.20].map{ button(String(format:"%.0f%%",$0*100),action:"uiScale",value:String($0),isActive:abs(s.uiScale-$0)<0.01)}.joined())</div></div>
                      <div class='row'><div><div class='label'>Window motion</div><div class='detail'>Controls the intensity of spatial window animations.</div></div><div class='choices'>\(button("Reduced",action:"animation",value:"0.35",isActive:s.animationIntensity<0.6))\(button("Full",action:"animation",value:"1.0",isActive:s.animationIntensity>=0.6))</div></div>
                      <div class='row'><div><div class='label'>Battery saver</div><div class='detail'>Reduces decorative work while preserving desktop state.</div></div><div class='choices'>\(button(s.batterySaver ? "On":"Off",action:"batterySaver",value:"",isActive:s.batterySaver))</div></div>
                      <div class='row stack'><div class='label'>Windows</div><div class='choices'>\(button("Save now",action:"saveWorkspace",value:""))\(button("Restore saved desktop",action:"restoreWorkspace",value:""))\(button("Minimize all",action:"minimizeAll",value:""))\(button("Restore all",action:"restoreAll",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='browser'>
                    <h1>Browser & Safari</h1><div class='lead'>\(s.bookmarkCount) bookmarks · \(s.historyCount) history items</div>
                    <h2>Safari & Security</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Safari Bookmarks & Favorites Bar</div><div class='detail'>\(esc(s.importMessage))</div></div><div class='choices'>\(button("Import…",action:"importSafari",value:""))</div></div>
                      <div class='row'><div><div class='label'>Passkeys & Face ID Sign-In</div><div class='detail'>WebAuthn and passkeys trigger authentication takeover on iPhone.</div></div><div class='choices'>\(button("Test on iPhone…",action:"passkeyTakeover",value:""))</div></div>
                      <div class='row'><div><div class='label'>History</div><div class='detail'>Clears Kamihi Browser history without changing Safari.</div></div><div class='choices'>\(button("Clear history",action:"clearHistory",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='setup'>
                    <h1>General</h1><div class='lead'>Desktop setup and onboarding.</div>
                    <h2>Getting Started</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Desktop onboarding</div><div class='detail'>Review gestures, display setup and browser import again.</div></div><div class='choices'>\(button("Open onboarding…",action:"onboarding",value:""))</div></div>
                    </div>
                  </section>
                </div>
              </main>
            </div>
            <script>
              function send(action,value){window.webkit.messageHandlers.kamihiSettings.postMessage({action:action,value:value||''});}
              function go(id,button){document.querySelectorAll('.nav').forEach(x=>x.classList.remove('selected'));button.classList.add('selected');document.getElementById(id).scrollIntoView({behavior:'smooth',block:'start'});}
            </script>
            </body>
            </html>
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
