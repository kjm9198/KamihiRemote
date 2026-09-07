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
                --separator:rgba(127,127,127,.18);
                --sidebar-bg:rgba(246,246,246,.75);
                --card-bg:rgba(255,255,255,.70);
                --card-border:rgba(0,0,0,.08);
                --selected-nav:#0a84ff;
                --text-primary:rgba(0,0,0,.88);
                --text-secondary:rgba(0,0,0,.50);
              }
              @media (prefers-color-scheme: dark) {
                :root{
                  --sidebar-bg:rgba(36,36,38,.80);
                  --card-bg:rgba(44,44,46,.75);
                  --card-border:rgba(255,255,255,.10);
                  --text-primary:rgba(255,255,255,.92);
                  --text-secondary:rgba(255,255,255,.50);
                }
              }
              *{box-sizing:border-box}
              html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;color:var(--text-primary)}
              button,input{font:inherit}
              .shell{display:grid;grid-template-columns:236px minmax(0,1fr);width:100%;height:100%;background:rgba(127,127,127,.03)}
              
              /* macOS Sidebar */
              .sidebar{height:100%;padding:14px 10px 24px;background:var(--sidebar-bg);backdrop-filter:blur(36px) saturate(160%);-webkit-backdrop-filter:blur(36px) saturate(160%);border-right:.5px solid var(--separator);overflow-y:auto}
              
              /* Apple ID Profile Card */
              .profile-card{display:flex;align-items:center;gap:10px;padding:8px 10px 14px;margin-bottom:6px;border-bottom:.5px solid var(--separator)}
              .avatar{width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,#0a84ff,#5e5ce6);display:grid;place-items:center;color:white;font-size:18px;font-weight:600;box-shadow:0 2px 6px rgba(0,0,0,.15)}
              .profile-meta{display:flex;flex-direction:column}
              .profile-name{font-size:13px;font-weight:600;letter-spacing:-.15px}
              .profile-sub{font-size:10.5px;color:var(--text-secondary);margin-top:1px}
              
              .search-wrap{position:relative;margin:6px 2px 12px}
              .search-box{display:flex;align-items:center;gap:6px;height:28px;width:100%;padding:0 9px;border-radius:6px;background:rgba(127,127,127,.12);border:.5px solid rgba(127,127,127,.15);font-size:11.5px;color:inherit}
              .search-icon{font-size:11px;opacity:.55}
              
              .nav-section{margin-bottom:14px}
              .nav-label{font-size:9.5px;font-weight:700;text-transform:uppercase;letter-spacing:.3px;color:var(--text-secondary);padding:6px 10px 4px}
              
              .nav{display:flex;align-items:center;width:100%;height:32px;padding:0 8px;border:0;border-radius:6px;background:transparent;color:inherit;text-align:left;font-size:12px;font-weight:500;cursor:pointer;margin-bottom:1px;transition:background 0.12s}
              .nav:hover{background:rgba(127,127,127,.09)}
              .nav.selected{background:var(--selected-nav);color:white;font-weight:600}
              .nav.selected .ico{box-shadow:none}
              
              .ico{display:grid;place-items:center;width:20px;height:20px;margin-right:9px;border-radius:5px;color:white;font-size:10.5px;font-weight:700;box-shadow:0 1px 2px rgba(0,0,0,.15)}
              .blue{background:#007aff}.purple{background:#af52de}.green{background:#34c759}.orange{background:#ff9500}.pink{background:#ff2d55}.gray{background:#8e8e93}.cyan{background:#32ade6}.indigo{background:#5856d6}
              
              /* Right Content Pane */
              .main{height:100%;overflow-y:auto;scroll-behavior:smooth}
              .toolbar{position:sticky;top:0;z-index:10;display:flex;align-items:center;justify-content:space-between;height:48px;padding:0 24px;background:var(--sidebar-bg);backdrop-filter:blur(36px) saturate(160%);-webkit-backdrop-filter:blur(36px) saturate(160%);border-bottom:.5px solid var(--separator)}
              .toolbar strong{font-size:13px;font-weight:650}
              .status{display:flex;align-items:center;gap:6px;font-size:11px;color:var(--text-secondary)}
              .dot{width:7px;height:7px;border-radius:99px;background:#34c759}
              .offline .dot{background:#ff9500}
              
              .content{max-width:740px;margin:0 auto;padding:26px 28px 50px}
              .section{scroll-margin-top:60px;margin-bottom:32px}
              h1{font-size:22px;line-height:1.15;letter-spacing:-.45px;margin:0 0 4px}
              .lead{font-size:11.5px;color:var(--text-secondary);margin-bottom:18px}
              h2{font-size:12.5px;font-weight:600;color:var(--text-secondary);margin:0 0 7px;padding-left:3px;text-transform:uppercase;letter-spacing:.2px}
              
              /* Inset Grouped Box */
              .group{overflow:hidden;border:.5px solid var(--card-border);border-radius:10px;background:var(--card-bg);backdrop-filter:blur(24px) saturate(140%);-webkit-backdrop-filter:blur(24px) saturate(140%);box-shadow:0 1px 4px rgba(0,0,0,.04);margin-bottom:20px}
              .row{display:flex;align-items:center;justify-content:space-between;gap:16px;min-height:44px;padding:9px 14px;border-top:.5px solid var(--separator)}
              .row:first-child{border-top:0}
              .row.stack{display:block;padding-top:11px;padding-bottom:12px}
              .label{font-size:12px;font-weight:550}
              .detail{font-size:10.5px;color:var(--text-secondary);line-height:1.35;margin-top:2px}
              .value{font-size:11px;color:var(--text-secondary);white-space:nowrap}
              
              .choices{display:flex;flex-wrap:wrap;justify-content:flex-end;gap:6px}
              .stack .choices{justify-content:flex-start;margin-top:8px}
              
              .choice{appearance:none;border:.5px solid rgba(127,127,127,.24);background:rgba(127,127,127,.10);color:inherit;border-radius:6px;padding:4px 10px;min-height:26px;font-size:11px;font-weight:550;cursor:pointer;transition:all .1s}
              .choice:hover{background:rgba(127,127,127,.16)}
              .choice.active{background:var(--accent);border-color:var(--accent);color:white;font-weight:600}
              .choice.danger{color:#ff453a}
              
              .step{display:flex;align-items:center;gap:6px}
              .step button{width:26px;height:24px;border:.5px solid rgba(127,127,127,.24);border-radius:5px;background:rgba(127,127,127,.10);color:inherit;font-size:14px;cursor:pointer}
              .range{display:flex;align-items:center;gap:10px;min-width:240px}
              .range input{accent-color:var(--accent);width:170px}
              .range span{width:38px;text-align:right;font-size:10.5px;color:var(--text-secondary)}
              .empty{font-size:11px;color:var(--text-secondary);padding:4px 0}
              
              @media(max-width:700px){
                .shell{grid-template-columns:190px minmax(0,1fr)}
                .content{padding:18px 14px}
                .range{min-width:180px}.range input{width:120px}
              }
              </style>
            </head>
            <body>
            <div class='shell'>
              <aside class='sidebar'>
                <div class='profile-card'>
                  <div class='avatar'></div>
                  <div class='profile-meta'>
                    <span class='profile-name'>Kamihi User</span>
                    <span class='profile-sub'>Apple ID & iCloud</span>
                  </div>
                </div>

                <div class='search-wrap'>
                  <div class='search-box'><span class='search-icon'>⌕</span>Search settings</div>
                </div>

                <div class='nav-section'>
                  <div class='nav-label'>Appearance & Display</div>
                  <button class='nav selected' onclick="go('appearance',this)"><span class='ico purple'>◐</span>Appearance</button>
                  <button class='nav' onclick="go('display',this)"><span class='ico blue'>▣</span>Displays</button>
                  <button class='nav' onclick="go('desktop',this)"><span class='ico green'>▤</span>Desktop & Dock</button>
                </div>

                <div class='nav-section'>
                  <div class='nav-label'>Input & Hardware</div>
                  <button class='nav' onclick="go('trackpad',this)"><span class='ico gray'>⌁</span>Trackpad & Mouse</button>
                </div>

                <div class='nav-section'>
                  <div class='nav-label'>System & Apps</div>
                  <button class='nav' onclick="go('browser',this)"><span class='ico cyan'>◉</span>Safari & Bookmarks</button>
                  <button class='nav' onclick="go('setup',this)"><span class='ico orange'>✦</span>General & Setup</button>
                </div>
              </aside>

              <main class='main' id='main'>
                <div class='toolbar'>
                  <strong>System Settings</strong>
                  <div class='status\(s.connected ? "" : " offline")'><span class='dot'></span>\(s.connected ? "External display connected" : "Desktop Lab ready")</div>
                </div>
                <div class='content'>
                  <section class='section' id='appearance'>
                    <h1>Appearance</h1>
                    <div class='lead'>macOS Liquid Glass, desktop wallpaper and system color theme.</div>
                    <h2>Theme & Materials</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Appearance Theme</div><div class='detail'>Match iPhone mode or stay dark/light.</div></div><div class='choices'>\(themeButtons)</div></div>
                      <div class='row'><div><div class='label'>Liquid Glass Diffusion</div><div class='detail'>Diffusion style for title bars, Dock, and sidebars.</div></div><div class='choices'>\(glassButtons)</div></div>
                      <div class='row'><div><div class='label'>Glass Clarity</div><div class='detail'>Adjust transparency against background windows.</div></div><div class='range'><input type='range' min='0' max='1' value='\(s.glassClarity)' step='.05' onchange="send('glassClarity',this.value)"><span>\(Int((s.glassClarity*100).rounded()))%</span></div></div>
                      <div class='row'><div><div class='label'>Specular Highlight Borders</div><div class='detail'>Glass bevel edge separating active windows.</div></div><div class='choices'>\(button(s.glassHighlights ? "On" : "Off", action:"glassHighlights", value:"", isActive:s.glassHighlights))</div></div>
                      <div class='row stack'><div class='label'>Wallpaper & Photos</div><div class='detail'>Choose an atmospheric wallpaper or upload your own photo.</div><div class='choices'>\(wallpaperButtons)\(s.hasCustomPhoto ? button("Custom Photo", action:"customWallpaper", value:"", isActive:s.wallpaperID == "custom") : "")\(button("Choose / Upload…", action:"openWallpaper", value:""))\(button(s.showWidgets ? "Widgets On" : "Widgets Off", action:"widgets", value:"", isActive:s.showWidgets))</div></div>
                    </div>
                  </section>

                  <section class='section' id='display'>
                    <h1>Displays</h1><div class='lead'>\(esc(s.capabilitySummary)) · \(esc(s.calibrationSummary))</div>
                    <h2>External Display & RayNeo</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>ProMotion Refresh Rate</div><div class='detail'>120 Hz offers ultra-fluid cursor movement and zero jitter.</div></div><div class='choices'>\(button("60 Hz",action:"refresh",value:"60",isActive:s.preferredRefreshRate == 60))\(button("120 Hz (ProMotion)",action:"refresh",value:"120",isActive:s.preferredRefreshRate == 120))</div></div>
                      <div class='row stack'><div class='label'>Connected Display Modes</div><div class='detail'>Hardware resolution and timings reported by the external display.</div><div class='choices'>\(modeButtons)</div></div>
                      <div class='row'><div><div class='label'>Horizontal Safe Area Trim</div><div class='detail'>Keep content from being cut off by TV or glasses borders.</div></div><div class='step'><span class='value'>\(Int((s.horizontalSafeMargin*100).rounded()))%</span><button onclick="send('safeH','down')">−</button><button onclick="send('safeH','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Vertical Safe Area Trim</div><div class='detail'>Vertical edge alignment compensation.</div></div><div class='step'><span class='value'>\(Int((s.verticalSafeMargin*100).rounded()))%</span><button onclick="send('safeV','down')">−</button><button onclick="send('safeV','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Display Calibration</div><div class='detail'>Reset all overscan trims to factory default.</div></div><div class='choices'>\(button("Reset All",action:"resetCalibration",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='desktop'>
                    <h1>Desktop & Dock</h1><div class='lead'>macOS-style Dock behavior, edge-to-edge window bounds and workspaces.</div>
                    <h2>Dock</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Automatically hide and show the Dock</div><div class='detail'>Dock stays hidden until cursor hovers at the bottom of the screen.</div></div><div class='choices'>\(button(s.autohideDock ? "On":"Off",action:"autohideDock",value:"",isActive:s.autohideDock))</div></div>
                      <div class='row'><div><div class='label'>Dock Auto-Hide Action</div><div class='detail'>Toggle hiding without leaving your current workspace.</div></div><div class='choices'>\(button(s.autohideDock ? "Keep Dock Visible" : "Turn Off Dock",action:"autohideDock",value:""))</div></div>
                    </div>

                    <h2>Windows & Workspaces</h2>
                    <div class='group'>
                      <div class='row stack'><div class='label'>Default Workspace Preset</div><div class='choices'>\(workspaceButtons)</div></div>
                      <div class='row'><div><div class='label'>Interface Scale</div></div><div class='choices'>\([0.90,1.00,1.10,1.20].map{ button(String(format:"%.0f%%",$0*100),action:"uiScale",value:String($0),isActive:abs(s.uiScale-$0)<0.01)}.joined())</div></div>
                      <div class='row'><div><div class='label'>Spatial Window Motion</div><div class='detail'>Smooth fluid springs when zooming or snapping windows.</div></div><div class='choices'>\(button("Reduced",action:"animation",value:"0.35",isActive:s.animationIntensity<0.6))\(button("Full",action:"animation",value:"1.0",isActive:s.animationIntensity>=0.6))</div></div>
                      <div class='row'><div><div class='label'>Low Power Mode</div><div class='detail'>Reduces background overhead while preserving open documents.</div></div><div class='choices'>\(button(s.batterySaver ? "On":"Off",action:"batterySaver",value:"",isActive:s.batterySaver))</div></div>
                      <div class='row stack'><div class='label'>Window Management</div><div class='choices'>\(button("Save Workspace",action:"saveWorkspace",value:""))\(button("Restore Saved",action:"restoreWorkspace",value:""))\(button("Minimize All",action:"minimizeAll",value:""))\(button("Restore All",action:"restoreAll",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='trackpad'>
                    <h1>Trackpad & Mouse</h1><div class='lead'>The iPhone screen acts as a multi-touch macOS precision trackpad.</div>
                    <h2>Tracking & Clicks</h2>
                    <div class='group'>
                      <div class='row stack'><div class='label'>Pointer Dynamics Profile</div><div class='choices'>\(profileButtons)</div></div>
                      <div class='row'><div><div class='label'>Tracking Speed</div><div class='detail'>Pointer velocity gain for standard finger travel.</div></div><div class='step'><span class='value'>\(String(format:"%.2fx",s.pointerSensitivity))</span><button onclick="send('pointerSpeed','down')">−</button><button onclick="send('pointerSpeed','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Acceleration Curve</div></div><div class='step'><span class='value'>\(String(format:"%.1f",s.pointerAcceleration))</span><button onclick="send('pointerAcceleration','down')">−</button><button onclick="send('pointerAcceleration','up')">+</button></div></div>
                      <div class='row'><div><div class='label'>Scroll Speed</div></div><div class='step'><span class='value'>\(String(format:"%.1fx",s.scrollSpeed))</span><button onclick="send('scrollSpeed','down')">−</button><button onclick="send('scrollSpeed','up')">+</button></div></div>
                      <div class='row stack'><div class='label'>Gestures & Physics</div><div class='choices'>\(button(s.naturalScrolling ? "Natural Scrolling":"Reverse Scrolling",action:"naturalScrolling",value:"",isActive:s.naturalScrolling))\(button(s.scrollMomentum ? "Inertial Momentum":"Linear",action:"scrollMomentum",value:"",isActive:s.scrollMomentum))\(button(s.tapToClick ? "Tap to Click":"Press to Click",action:"tapToClick",value:"",isActive:s.tapToClick))\(button(s.dragLock ? "Drag Lock":"Instant Release",action:"dragLock",value:"",isActive:s.dragLock))\(button(s.haptics ? "Haptic Feedback":"Silent",action:"haptics",value:"",isActive:s.haptics))</div></div>
                      <div class='row stack'><div class='label'>Software Cursor Icon</div><div class='choices'>\(cursorButtons)</div></div>
                    </div>
                  </section>

                  <section class='section' id='browser'>
                    <h1>Safari & Bookmarks</h1><div class='lead'>\(s.bookmarkCount) bookmarks imported · \(s.historyCount) browsing history items</div>
                    <h2>Safari Sync & Passkeys</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Safari Bookmarks & Favorites Import</div><div class='detail'>\(esc(s.importMessage))</div></div><div class='choices'>\(button("Import from Files…",action:"importSafari",value:""))</div></div>
                      <div class='row'><div><div class='label'>Passkeys & Biometric Face ID Takeover</div><div class='detail'>Seamlessly authenticate logins on your iPhone without leaving the desktop.</div></div><div class='choices'>\(button("Test Passkey on iPhone…",action:"passkeyTakeover",value:""))</div></div>
                      <div class='row'><div><div class='label'>Browsing History</div><div class='detail'>Clears local desktop tab session history securely.</div></div><div class='choices'>\(button("Clear History",action:"clearHistory",value:""))</div></div>
                    </div>
                  </section>

                  <section class='section' id='setup'>
                    <h1>General & Setup</h1><div class='lead'>System onboarding and device calibration.</div>
                    <h2>Getting Started</h2>
                    <div class='group'>
                      <div class='row'><div><div class='label'>Desktop Setup Tutorial</div><div class='detail'>Re-run the interactive onboarding tour for trackpad gestures and glasses setup.</div></div><div class='choices'>\(button("Launch Setup Tour…",action:"onboarding",value:""))</div></div>
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
