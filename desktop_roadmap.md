# Kamihi Desktop — Complete Feature Roadmap

Status legend: `VERIFIED` = implemented and covered by available automated/CI evidence; `IMPLEMENTED / PHYSICAL TEST` = implemented but requires real iPhone + external display verification; `PARTIAL` = useful slice exists but feature is not complete; `TODO` = not implemented yet; `IOS LIMITATION` = iOS does not expose the same system-level capability as Samsung DeX, so implement the closest public-API equivalent.

## Core desktop and windowing

| # | Feature | Status | Evidence / next requirement |
|---:|---|---|---|
| 1 | Instant Desktop Mode on external display | IMPLEMENTED / PHYSICAL TEST | External noninteractive scene + automatic controller switch; Apple Build and simulator-host smoke green on `5eca7498`; verify with RayNeo Air 4 Pro. |
| 2 | Real window manager | PARTIAL | Move, focus, minimize, maximize, close plus controller resizing/centering exist; direct resize handles still TODO. |
| 3 | Smart snapping 1/2, 1/3, 2/3, 1/4 | PARTIAL | Halves, thirds and quarters plus guarded title-bar drag edge/corner preview and release-to-snap are implemented on `864dd1d`; direct resize handles and richer spatial/workspace behavior remain. |
| 4 | Vibe Coding Workspace | IMPLEMENTED / PHYSICAL TEST | ChatGPT + YouTube + Notes layout exists; integration smoke green on `5eca7498`; physical display interaction still required. |
| 5 | Saved workspace presets | PARTIAL | Vibe/Work/Study/Entertainment/Focus service presets exist; richer editor TODO. |
| 6 | Workspace restoration | PARTIAL | Window session serialization/restoration + reconnect restoration + continuous autosave exist; recovery snapshot now added and awaiting final-head CI/real interruption validation. |
| 7 | Desktop taskbar | PARTIAL | Running app/taskbar surface exists; richer status/running indicators TODO. |
| 8 | Searchable app launcher | VERIFIED | Searchable phone launcher is wired into the connected controller and compiled/smoked on `5eca7498`. |
| 9 | Command palette | VERIFIED | Searchable command center is live with app, layout, save and resize commands; Apple Build green on `5eca7498`. |
| 10 | Dedicated ChatGPT desktop app | IMPLEMENTED / PHYSICAL TEST | Desktop WebKit ChatGPT window; auth/input real-device verification required. |
| 11 | AI quick panel | TODO | Overlay panel using ChatGPT window/web/API-safe route. |
| 12 | Voice-to-AI | PARTIAL | Existing KamihiRemote dictation infrastructure exists; route into Desktop active AI window TODO. |
| 13 | YouTube desktop app | IMPLEMENTED / PHYSICAL TEST | Desktop WebKit YouTube window with inline media; physical playback verification required. |
| 14 | Video Picture-in-Picture | TODO | Use public AVKit/WebKit PiP support where available. |
| 15 | Native Kamihi Notes | PARTIAL | Local autosaving notes store + desktop view + phone editor exist; desktop keyboard editing TODO. |
| 16 | AI -> Notes handoff | PARTIAL | Clipboard Center can append selected/copied text directly to Notes; direct response-selection affordance TODO. |
| 17 | Files app | PARTIAL | Native Files window imports through the public system document picker in copy mode and persists Kamihi-owned copies in Application Support; richer organization/export workflows remain. |
| 18 | PDF viewer | PARTIAL | Native PDFKit continuous-page viewer with auto scaling is wired into Files on `678cf9c`; real-device/external-display interaction still needs physical validation. |
| 19 | Photos window | IMPLEMENTED / PHYSICAL TEST | `3f657b6` replaces the placeholder with a native PhotoKit viewer. Explicitly opening Photos triggers the public iOS read/write permission flow, supports both full and Limited Library access, shows up to the 60 newest granted image assets, and does not copy/log/upload the library. Apple Build and Apple Integration Smoke passed on attempt 1; real permission UI, limited-selection behavior, iCloud-backed thumbnails and RayNeo viewing remain physical checks. |
| 20 | Clipboard manager | PARTIAL | 20-item clipboard history service plus phone Clipboard Center exists; persistence/privacy controls TODO. |
| 21 | Multiple desktop workspaces | PARTIAL | Workspace presets exist; swipeable independent Spaces/state TODO. |
| 22 | Mission Control / overview | VERIFIED | Phone Window Overview now shows each current window as a lightweight spatial mini-map using its real effective frame, exposes active/maximized/minimized state, activates/restores the selected window, and restores minimized windows without launching or mutating into the optional Vibe workspace. Focus 4 feature/fix heads `9eb9f9a` → `d11436e`; Apple Build and Apple Integration Smoke passed on attempt 1. |
| 23 | Command/Alt-Tab window switching | PARTIAL | Forward/back window cycling logic exists; physical keyboard binding/UI TODO. |
| 24 | Advanced iPhone trackpad | PARTIAL | Pointer, drag, scrolling, right-click exist; acceleration/natural scroll/drag-lock settings TODO. |
| 25 | DeX-style context click | IMPLEMENTED / PHYSICAL TEST | Two-finger secondary click forwards contextmenu to web apps; real external display validation required. |
| 26 | Physical mouse support | IOS LIMITATION | Support public indirect pointer events where iOS routes them; cannot take over arbitrary system pointer routing. |
| 27 | Physical keyboard support | PARTIAL | iOS keyboard support and several SwiftUI keyboardShortcut bindings exist; full desktop focus/shortcut routing TODO. |
| 28 | Phone keyboard mode | PARTIAL | Phone text field forwards text/Enter to active web app; full keyboard surface/modifiers TODO. |
| 29 | Phone shortcut deck | PARTIAL | ChatGPT/YouTube/Notes/Split/Vibe quick actions exist; customization TODO. |
| 30 | Phone media controls | TODO | Add public media controls for Kamihi-owned playback/web commands. |

## Desktop utilities and interaction

| # | Feature | Status | Evidence / next requirement |
|---:|---|---|---|
| 31 | Notification center | IOS LIMITATION | Cannot mirror arbitrary iOS notifications; build Kamihi-owned notification center. |
| 32 | Quick Settings | VERIFIED | UI scale, cursor scale, animation, battery saver, privacy, workspace and window layout controls are surfaced; `5eca7498` Apple Build is green. |
| 33 | Desktop screenshots | IMPLEMENTED / PHYSICAL TEST | User-triggered capture renders Kamihi's external-display window at the iOS-negotiated native backing scale and hands the image to the standard iPhone share sheet. Feature head `5a581dfb`; Apple Build, deploy and Apple Integration Smoke passed, with smoke on attempt 1. Verify WebKit/video capture fidelity and RayNeo share behavior physically. |
| 34 | Screenshot -> ChatGPT | TODO | User-initiated captured image handoff only. |
| 35 | Focus Mode | PARTIAL | Focus workspace state exists; hide taskbar/extra chrome TODO. |
| 36 | Presentation Mode | PARTIAL | Existing KamihiRemote presentation controls can be integrated into desktop shell. |
| 37 | Reader Mode | TODO | Reader-oriented browser mode/public WebKit transformations. |
| 38 | Glasses large-text mode | PARTIAL | UI scale preference/service exists; automatic scene application TODO. |
| 39 | RayNeo Air 4 Pro profile | PARTIAL | 16:9/glasses display classifier exists; physical RayNeo calibration TODO. |
| 40 | Display calibration | IMPLEMENTED / PHYSICAL TEST | Persisted horizontal/vertical safe margins already move desktop content inward; Focus 1 adds a high-contrast external calibration guide with outer edges, corner marks, grid, safe-frame outline, and negotiated resolution/refresh readout. It appears briefly on canvas/display-metric changes and remains visible while margins are nonzero. Physical RayNeo overscan validation remains required. |
| 41 | Adaptive UI scaling | PARTIAL | Display metrics + recommended scale logic exists; automatic scene application TODO. |
| 42 | Battery Saver Desktop Mode | PARTIAL | Low Power Mode/override/thermal state service exists; inactive web-backed windows can sleep during conservation, and `2fe7600` additionally suppresses non-essential launcher/snap transitions and launcher shadow work under iOS Low Power Mode or serious/critical thermal pressure while keeping pointer/window/WebKit interaction responsive. Physical energy profiling remains TODO. |
| 43 | WebView sleeping | PARTIAL | Minimized/inactive web-backed windows already sleep under conservation. `e4ad849` now also releases inactive retained Browser `WKWebView`s whenever iOS sends a memory warning or the app backgrounds, while Low Power Mode reduces the Browser warm pool from six renderers to two. Active tabs remain live and inactive tabs preserve URL/title/session metadata for lazy recreation. Long-idle policy and physical memory-pressure profiling remain TODO. |
| 44 | Thermal protection | PARTIAL | Live ProcessInfo thermal monitoring and saver trigger exist; serious/critical thermal pressure participates in inactive web-window sleeping and now disables purely decorative external-desktop motion/shadow work on `2fe7600`. Physical thermal profiling and richer media throttling remain TODO. |
| 45 | Battery/time indicator | PARTIAL | Live battery level/state exists; taskbar estimate/session projection TODO. |
| 46 | Smooth efficient cursor | PARTIAL | Software cursor exists; frame pacing/acceleration profiling on device TODO. |
| 47 | Window animation system | PARTIAL | Snappy transitions respect Reduce Motion; external desktop snap/launcher decorative motion is also suppressed under iOS Low Power Mode and serious/critical thermal pressure on `2fe7600`. Full transition vocabulary remains TODO. |
| 48 | Kamihi drag-and-drop | TODO | Public Transferable/drag/drop between supported Kamihi content. |
| 49 | Universal search | PARTIAL | Command/app search infrastructure exists; notes/tabs/files indexing TODO. |
| 50 | Browser tabs | TODO | Multi-WebKit tab/session model. |
| 51 | Browser profiles | TODO | Separate permitted WebKit data stores; define privacy semantics. |
| 52 | Downloads manager | TODO | WKDownload/document storage within app sandbox/document picker. |
| 53 | Bookmark bar | TODO | Persisted user bookmarks and shortcuts. |
| 54 | GitHub workspace | TODO | GitHub web view and/or connected authenticated workflow without exposing secrets. |
| 55 | Remote Mac/PC window | PARTIAL | Existing KamihiRemote host/secure transport exists; keep dormant for backward compatibility/regression unless explicitly required; do not expose as a normal launch compartment. |
| 56 | Development project launcher | PARTIAL | Existing Vibe/project infrastructure exists; desktop launcher integration TODO. |
| 57 | Dictated coding changes | PARTIAL | Existing speech workflow exists; active desktop target routing TODO. |
| 58 | AI clipboard actions | PARTIAL | Quick paste and Add to Notes exist; Explain/Rewrite/Translate/Fix actions TODO. |
| 59 | Session history | PARTIAL | Current workspace serialization and last-known-good recovery snapshot exist; recent closed/history list TODO. |
| 60 | Crash recovery | PARTIAL | Recovery coordinator persists last-known-good workspace/window snapshot, tracks clean exit, and restores after an unclean desktop session; autosave bursts are now coalesced on `3bd3e5c` to reduce repeated persistence work during drag/resize. Abnormal-termination physical validation remains pending. |
| 61 | Offline Notes/Calculator/Files | PARTIAL | Notes, local Calculator, and imported Kamihi-owned document copies work offline; broader file creation/export workflows remain. |
| 62 | Connection Doctor | PARTIAL | Existing KamihiRemote connection doctor exists; desktop recovery coordinator now tracks connected/recovered/disconnected state, but cable/RayNeo diagnostics UI integration TODO. |
| 63 | External display test screen | IMPLEMENTED / PHYSICAL TEST | Display metrics + RayNeo checklist now pair with an on-canvas high-contrast calibration pattern that exposes the four physical edges/corners, quarter/center grid, safe-frame outline, and iOS-negotiated output/refresh summary. Physical glasses verification remains required. |
| 64 | Accessibility mode | PARTIAL | Reduce Motion and transparency-aware shell behavior exist; `ebd5b3d` adds a VoiceOver-friendly, Dynamic-Type-based Keyboard & Gestures guide plus cleaner command-row accessibility. Contrast/focus-navigation audit and preset profiles remain TODO. |
| 65 | Privacy screen/lock | PARTIAL | Privacy blur/lock plus LocalAuthentication Face ID/device-passcode unlock are implemented; real-device authentication verification TODO. |
| 66 | Desktop lock screen | PARTIAL | LocalAuthentication-gated locked overlay exists; lock-on-background/timeout policy TODO. |
| 67 | Low-distraction notifications | TODO | Kamihi-owned notification banners only. |
| 68 | Quick calculations/conversions | PARTIAL | Local calculator is implemented in the controller; unit/currency conversion commands TODO. |
| 69 | Clock/timer panel | PARTIAL | Clock exists; focus timer service exists; richer panel UI TODO. |
| 70 | Pomodoro/Focus timer | PARTIAL | 25-minute configurable timer engine exists; completion notification/presets TODO. |

## Newly discovered high-value features

| # | Feature | Status | Why it matters / next requirement |
|---:|---|---|---|
| 71 | Browser back/forward/reload controls | VERIFIED | Active WebKit bridge exposes back/forward/reload/stop controls from the phone controller; Apple Build + simulator-host smoke green on `5eca7498`. |
| 72 | Desktop browser address/search bar | VERIFIED | Phone controller provides URL/search entry with URL normalization and search fallback; Apple Build + simulator-host smoke green on `5eca7498`. |
| 73 | Favorites + recent sites | TODO | One-tap workspace startup and faster glasses use. |
| 74 | Web app pinning | TODO | Pin ChatGPT/GitHub/YouTube/custom sites as Desktop apps. |
| 75 | Hardware keyboard shortcut layer | PARTIAL | Cmd-K, launcher/settings/save shortcuts are present in controller UI; close/cycle/layout shortcut coverage and focus routing TODO. |
| 76 | Trackpad tuning | TODO | Pointer sensitivity, acceleration curve, natural scrolling, drag lock and tap-to-click controls. |
| 77 | Drag-edge snap preview | IMPLEMENTED / PHYSICAL TEST | Active title-bar drags show the existing target rectangle and commit edge/corner/maximize snap only on release; moving away cancels. Feature head `864dd1d`; Apple Build + Integration Smoke passed attempt 1. Real iPhone/RayNeo drag feel remains a physical check. |
| 78 | Continuous session autosave | VERIFIED | Recovery remains leading-edge immediate but rapid drag/resize state changes are now coalesced into a single trailing snapshot at most every 0.75 s on `3bd3e5c`; finish/disconnect still flushes synchronously. Apple Build passed attempt 1 and Apple Integration Smoke’s core smoke step passed attempt 1. |
| 79 | External-display health banner | PARTIAL | Recovery coordinator exposes connected/recovered/disconnected health state; visible recovery/health banner still TODO. |
| 80 | RayNeo safe-area calibration | IMPLEMENTED / PHYSICAL TEST | User-adjustable horizontal/vertical margins persist in UserDefaults and move only Kamihi content inward, never changing the mode negotiated by iOS. Focus 1 adds visible outer-edge/corner/grid and calibrated-safe-frame feedback so overscan can be tuned while looking through the glasses. Physical Air 4 Pro calibration remains required. |
| 81 | Web app lifecycle sleeping | PARTIAL | `074a64c` unloads minimized content and conservation-mode inactive Browser/ChatGPT/YouTube windows. `e4ad849` adds Browser-specific memory-pressure/background cleanup and a Low Power Mode warm-pool cap of two retained renderers, while persistent WebKit website data and browser URL/session metadata remain outside the renderer lifetime. Physical memory/thermal profiling and a deliberate long-idle policy remain TODO. |
| 82 | Document import center | PARTIAL | System document picker imports copies into a persistent Kamihi Application Support library with collision-safe names; organization/export/edit-in-place workflows remain. |
| 83 | Quick Paste to active app | IMPLEMENTED / PHYSICAL TEST | Clipboard Center can inject text into the active supported WebKit/AI editor; physical external-display input validation required. |
| 84 | Desktop capture/share | IMPLEMENTED / PHYSICAL TEST | `5a581dfb` exposes Capture Desktop from both wide and compact phone-controller layouts, snapshots only Kamihi's external desktop at native backing scale, and uses the standard iOS share sheet without broad Photos permission or automatic saving. Apple Build/deploy/Integration Smoke passed, smoke attempt 1. Physical RayNeo/WebKit/video fidelity remains required. |
| 85 | Recovery snapshot | PARTIAL | Versioned last-known-good snapshot stores workspace, timestamp and up to eight window states; `3bd3e5c` reduces persistence churn during continuous window manipulation while keeping immediate session-boundary flushes. |
| 86 | Connection quality HUD | TODO | Surface display/session health, host latency when remote mode is used, and actionable warnings. |
| 87 | Workspace template editor | TODO | Let user save custom window/app layouts beyond the built-in five presets. |
| 88 | Fullscreen app mode | TODO | One-command distraction-free fullscreen with quick return to previous layout. |
| 89 | Keyboard command cheat sheet | PARTIAL | `ebd5b3d` adds a discoverable Keyboard & Gestures sheet from the Command Palette covering phone trackpad gestures, window cycling, keyboard entry, Precision Mode and Continue-on-iPhone. Exact hardware-keyboard shortcut inventory and close/cycle/layout bindings remain TODO. |
| 90 | Accessibility preset profiles | TODO | Large text/high contrast/reduced motion/glasses comfort presets. |

## Verification gates

A feature is not `VERIFIED` until all applicable gates pass:

1. iOS simulator compile.
2. macOS host compile/regression check if shared code changed.
3. Relevant deterministic self-checks pass on DEBUG launch or CI harness.
4. Accessibility/Reduce Motion behavior checked for UI features.
5. Low Power Mode behavior checked for animation/media/background features.
6. External display features are exercised on physical iPhone hardware.
7. RayNeo-specific features are exercised on the RayNeo Air 4 Pro and remain `PHYSICAL TEST` before that.
8. Existing KamihiRemote remote-control behavior remains intact.
9. Only public Apple APIs are used.
10. No Samsung branding, proprietary assets, or copied trade dress are included; only useful desktop interaction concepts are reproduced with Kamihi design.

## Current priority order

1. Continue richer workspace/spatial animations and independent multi-workspace behavior while preserving the now app-neutral spatial Window Overview; existing all-edge resize affordances and drag-edge snap preview should not be repeated.
2. Continue richer Files organization/export; the native Photos permission/viewer flow and desktop capture/share are now implemented and await physical fidelity checks.
3. Surface recovery/display-health UI and validate abnormal-termination restore behavior.
4. Add browser downloads/reader/pinning polish and a deliberate long-idle tab policy; memory-warning/background renderer cleanup and Low Power Mode warm-pool limiting are now implemented.
5. Add trackpad tuning and accessibility presets; safe-area calibration now has persisted margins plus visible external calibration guides and awaits physical RayNeo tuning.
6. Complete hardware-keyboard close/cycle/layout shortcuts; the first in-app Keyboard & Gestures guide is now present.
7. Keep legacy remote host/dev-project/dictation capabilities dormant unless shared regressions require work; normal launch remains Desktop-first.
8. Finish AI quick panel, AI clipboard actions, Notes handoff and media controls.
9. Finish polish, accessibility, RayNeo calibration and physical verification.

## Rotation evidence

- **2026-09-01 — Focus 8: Native desktop apps.** Persistent Files document library + native PDFKit viewing landed on feature head `678cf9c`. Apple Build and Apple Integration Smoke both passed on attempt 1. The normal launch remains Kamihi Desktop startup profiles; no Remote-for-Mac compartment was added or expanded.
- **2026-09-01 — Focus 9: Performance/energy/WebView lifecycle.** Added centralized `DesktopWindowEnergyPolicy`; minimized windows no longer retain fully hidden app/WebKit/media content, and Battery Saver/iOS Low Power Mode/serious-or-critical thermal pressure unload inactive Browser, ChatGPT and YouTube content while keeping the active window live. Login cookies stay in `WKWebsiteDataStore.default()` and Browser tab/URL metadata stays persisted, so sleeping does not read/store credentials. Feature head `074a64c`: iOS build, macOS regression build, Pages/deploy, and Apple Integration Smoke all passed; smoke passed on **attempt 1** with `exit_status=0`, one authenticated controller sync, and a visually clean Desktop Lab screenshot artifact. Real battery savings, memory pressure behavior, thermal response, media continuity and long-session stability remain `NEEDS PHYSICAL TEST`.
- **2026-09-01 — Focus 4 (current cycle): Windowing.** Restored guarded active-title-bar drag edge/corner snap intent. The preview appears only during an owned window drag, snap commits only on release, moving away cancels it, and ordinary pointer movement/two-finger resize remain isolated. Feature head `864dd1d`: Pages build/deploy, Apple Build, and Apple Integration Smoke all passed; smoke passed on **attempt 1**. The Desktop Lab artifact was visually inspected and remained clean/Desktop-first with no Remote-for-Mac compartment or obvious clipping/overlap regression. Real drag-edge snap feel on iPhone + RayNeo remains `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 9 (current cycle): Performance/energy.** Recovery autosave now preserves an immediate leading snapshot while coalescing rapid window-state bursts into one trailing write no more than every 0.75 s. Session start/end still flush immediately, so long-session drag/resize produces less JSON/UserDefaults churn without weakening normal disconnect recovery. Feature head `3bd3e5c`: iOS and full Apple Build passed on attempt 1; Apple Integration Smoke’s `Run iPhone + Mac integration smoke` step passed on attempt 1 and evidence upload succeeded. Real battery/flash-write savings and crash timing remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 7 (current cycle): Phone Takeover/authentication.** Takeover WebKit now keeps ordinary HTTP(S)/WebKit-owned navigation inside the secure iPhone sheet but hands non-web OAuth/SSO custom URL schemes to iOS through public `UIApplication.open`, preventing supported identity-provider app handoffs from dead-ending in WKWebView. No page/form values, passwords, passkeys, tokens or credentials are inspected or persisted by Kamihi. Feature head `51f03723`: Apple Build, Pages/deploy and Apple Integration Smoke all passed; smoke passed on **attempt 1**, evidence upload succeeded, `exit_status=0`, and the Desktop Lab screenshot was visually inspected as clean/Desktop-first with no Remote-for-Mac compartment or obvious clipping regression. Password AutoFill/passkeys, provider-specific app handoff, CAPTCHA/file picker, and ChatGPT/YouTube login remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 8 (current cycle): Native desktop apps.** Added user-triggered external-desktop capture/share. `5a581dfb` snapshots only Kamihi's external-display `UIWindow` at the iOS-negotiated native backing scale, exposes Capture Desktop in wide and compact phone-controller layouts, and presents the standard iPhone share sheet without automatic Photos saving or broad photo-library permission. Apple Build, deploy and Apple Integration Smoke all passed; smoke passed on **attempt 1**. Real RayNeo capture sharpness, WebKit/video capture fidelity and share-sheet behavior remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 9 (current cycle): Performance/energy.** External Desktop now observes the existing live iOS power/thermal monitor and suppresses purely decorative snap-preview/launcher animation plus the large launcher shadow when Low Power Mode is on or thermal pressure reaches serious/critical; Reduce Motion remains an equal trigger. Pointer movement, window manipulation and WebKit behavior are deliberately not throttled, so responsiveness is preserved. Feature head `2fe7600`; successor head `cb9eb394` is green across Apple Build, Pages/deploy and Apple Integration Smoke, with smoke passing on attempt 1. Physical battery/thermal benefit remains `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 8 (current cycle): Native desktop apps.** The existing Photos launcher tile now opens a real PhotoKit-backed desktop viewer instead of a placeholder. Explicit Photos launch requests iOS read/write authorization, respects full or Limited Library access, fetches only up to the 60 newest image assets granted by iOS, and keeps library ownership/privacy with the system—Kamihi does not copy, persist, log, or upload those assets. Purpose-string head `ea7b8c7` followed by feature head `3f657b6`; Apple Build passed on attempt 1, Apple Integration Smoke passed its trackpad contract + simulator/host smoke + evidence upload on attempt 1, and the Desktop Lab artifact was visually inspected as clean/Desktop-first. Real iPhone Photos permission UI, Limited selection changes, iCloud-backed thumbnails, and RayNeo photo readability remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 9 (current cycle, latest): Performance/energy and Browser renderer lifecycle.** Feature head `e4ad849` keeps the active Browser tab live but sheds every inactive retained `WKWebView` when iOS issues a memory warning or the app enters the background. Under iOS Low Power Mode, the MRU warm Browser pool is capped at two renderers instead of six. Persistent tab URL/title metadata and WebKit website data remain outside that renderer lifetime, so tabs can be lazily recreated without Kamihi inspecting or storing credentials. Apple Build and the trackpad-first contract passed on attempt 1; Apple Integration Smoke's real simulator+host step and evidence upload also passed on attempt 1, and the Desktop Lab artifact was visually inspected as clean/Desktop-first. Real memory-pressure recovery, background/foreground continuity, battery benefit and long-session stability remain `NEEDS PHYSICAL TEST`. **Next rotation: Focus 10 — keyboard/accessibility/polish.**
