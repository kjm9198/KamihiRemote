# Kamihi Desktop — Complete Feature Roadmap

Status legend: `VERIFIED` = implemented and covered by available automated/CI evidence; `IMPLEMENTED / PHYSICAL TEST` = implemented but requires real iPhone + external display verification; `PARTIAL` = useful slice exists but feature is not complete; `TODO` = not implemented yet; `IOS LIMITATION` = iOS does not expose the same system-level capability as Samsung DeX, so implement the closest public-API equivalent.

## Core desktop and windowing

| # | Feature | Status | Evidence / next requirement |
|---:|---|---|---|
| 1 | Instant Desktop Mode on external display | IMPLEMENTED / PHYSICAL TEST | External noninteractive scene + automatic controller switch; verify with RayNeo Air 4 Pro. |
| 2 | Real window manager | PARTIAL | Move, focus, minimize, maximize, close plus controller resizing/centering exist; direct resize handles still TODO. |
| 3 | Smart snapping 1/2, 1/3, 2/3, 1/4 | PARTIAL | Halves, thirds and quarters implemented; drag-edge snap detection TODO. |
| 4 | Vibe Coding Workspace | IMPLEMENTED / PHYSICAL TEST | ChatGPT + YouTube + Notes layout exists. |
| 5 | Saved workspace presets | PARTIAL | Vibe/Work/Study/Entertainment/Focus service presets exist; richer editor TODO. |
| 6 | Workspace restoration | PARTIAL | Window session serialization/restoration + reconnect restoration exist; continuous autosave TODO. |
| 7 | Desktop taskbar | PARTIAL | Running app/taskbar surface exists; richer status/running indicators TODO. |
| 8 | Searchable app launcher | IMPLEMENTED | Searchable phone launcher for Desktop apps is wired into the connected controller. |
| 9 | Command palette | IMPLEMENTED | Searchable command center is live with app, layout, save and resize commands. |
| 10 | Dedicated ChatGPT desktop app | IMPLEMENTED / PHYSICAL TEST | Desktop WebKit ChatGPT window; auth/input real-device verification required. |
| 11 | AI quick panel | TODO | Overlay panel using ChatGPT window/web/API-safe route. |
| 12 | Voice-to-AI | PARTIAL | Existing KamihiRemote dictation infrastructure exists; route into Desktop active AI window TODO. |
| 13 | YouTube desktop app | IMPLEMENTED / PHYSICAL TEST | Desktop WebKit YouTube window with inline media. |
| 14 | Video Picture-in-Picture | TODO | Use public AVKit/WebKit PiP support where available. |
| 15 | Native Kamihi Notes | PARTIAL | Local autosaving notes store + desktop view + phone editor exist; desktop keyboard editing TODO. |
| 16 | AI -> Notes handoff | TODO | Add selected/copied response action. |
| 17 | Files app | TODO | Public document picker + security-scoped access only. |
| 18 | PDF viewer | TODO | PDFKit window. |
| 19 | Photos window | TODO | PhotoKit with explicit limited/full permission handling. |
| 20 | Clipboard manager | PARTIAL | 20-item clipboard history service plus phone Clipboard Center exists; persistence/privacy controls TODO. |
| 21 | Multiple desktop workspaces | PARTIAL | Workspace presets exist; swipeable independent Spaces/state TODO. |
| 22 | Mission Control / overview | IMPLEMENTED | Phone Window Overview can activate, restore, minimize all and restore all windows. |
| 23 | Command/Alt-Tab window switching | PARTIAL | Forward/back window cycling logic exists; physical keyboard binding/UI TODO. |
| 24 | Advanced iPhone trackpad | PARTIAL | Pointer, drag, scrolling, right-click exist; acceleration/natural scroll/drag-lock settings TODO. |
| 25 | DeX-style context click | IMPLEMENTED / PHYSICAL TEST | Two-finger secondary click forwards contextmenu to web apps. |
| 26 | Physical mouse support | IOS LIMITATION | Support public indirect pointer events where iOS routes them; cannot take over arbitrary system pointer routing. |
| 27 | Physical keyboard support | PARTIAL | iOS keyboard support exists in project; desktop focus/shortcut routing TODO. |
| 28 | Phone keyboard mode | PARTIAL | Phone text field forwards text/Enter to active web app; full keyboard surface/modifiers TODO. |
| 29 | Phone shortcut deck | PARTIAL | ChatGPT/YouTube/Notes/Split/Vibe quick actions exist; customization TODO. |
| 30 | Phone media controls | TODO | Add public media controls for Kamihi-owned playback/web commands. |

## Desktop utilities and interaction

| # | Feature | Status | Evidence / next requirement |
|---:|---|---|---|
| 31 | Notification center | IOS LIMITATION | Cannot mirror arbitrary iOS notifications; build Kamihi-owned notification center. |
| 32 | Quick Settings | IMPLEMENTED | UI scale, cursor scale, animation, battery saver, privacy, workspace and window layout controls are surfaced. |
| 33 | Desktop screenshots | TODO | Capture Kamihi external desktop view using public rendering APIs. |
| 34 | Screenshot -> ChatGPT | TODO | User-initiated captured image handoff only. |
| 35 | Focus Mode | PARTIAL | Focus workspace state exists; hide taskbar/extra chrome TODO. |
| 36 | Presentation Mode | PARTIAL | Existing KamihiRemote presentation controls can be integrated into desktop shell. |
| 37 | Reader Mode | TODO | Reader-oriented browser mode/public WebKit transformations. |
| 38 | Glasses large-text mode | PARTIAL | UI scale preference/service exists; automatic scene application TODO. |
| 39 | RayNeo Air 4 Pro profile | PARTIAL | 16:9/glasses display classifier exists; physical RayNeo calibration TODO. |
| 40 | Display calibration | TODO | Safe-margin/scale test UI. |
| 41 | Adaptive UI scaling | PARTIAL | Display metrics + recommended scale logic exists; automatic scene application TODO. |
| 42 | Battery Saver Desktop Mode | PARTIAL | Low Power Mode/override/thermal state service exists; broader throttling TODO. |
| 43 | WebView sleeping | TODO | Suspend/reload minimized inactive web apps conservatively. |
| 44 | Thermal protection | PARTIAL | Live ProcessInfo thermal monitoring and saver trigger exist; media/background throttling TODO. |
| 45 | Battery/time indicator | PARTIAL | Live battery level/state exists; taskbar estimate/session projection TODO. |
| 46 | Smooth efficient cursor | PARTIAL | Software cursor exists; frame pacing/acceleration profiling on device TODO. |
| 47 | Window animation system | PARTIAL | Snappy transitions + Reduce Motion/low-power disable exist; full transition vocabulary TODO. |
| 48 | Kamihi drag-and-drop | TODO | Public Transferable/drag/drop between supported Kamihi content. |
| 49 | Universal search | PARTIAL | Command/app search infrastructure exists; notes/tabs/files indexing TODO. |
| 50 | Browser tabs | TODO | Multi-WebKit tab/session model. |
| 51 | Browser profiles | TODO | Separate permitted WebKit data stores; define privacy semantics. |
| 52 | Downloads manager | TODO | WKDownload/document storage within app sandbox/document picker. |
| 53 | Bookmark bar | TODO | Persisted user bookmarks and shortcuts. |
| 54 | GitHub workspace | TODO | GitHub web view and/or connected authenticated workflow without exposing secrets. |
| 55 | Remote Mac/PC window | PARTIAL | Existing KamihiRemote host/secure transport exists; embed as desktop app window TODO. |
| 56 | Development project launcher | PARTIAL | Existing Vibe/project infrastructure exists; desktop launcher integration TODO. |
| 57 | Dictated coding changes | PARTIAL | Existing speech workflow exists; active desktop target routing TODO. |
| 58 | AI clipboard actions | TODO | Explain/Rewrite/Translate/Fix/Add to Notes actions. |
| 59 | Session history | PARTIAL | Current workspace serialization exists; recent closed/history list TODO. |
| 60 | Crash recovery | PARTIAL | Persisted window model exists; automatic safe startup restore TODO. |
| 61 | Offline Notes/Calculator/Files | PARTIAL | Notes and local Calculator now work; document workflows TODO. |
| 62 | Connection Doctor | PARTIAL | Existing KamihiRemote connection doctor exists; external-display/cable/RayNeo diagnostics TODO. |
| 63 | External display test screen | PARTIAL | Display metrics + RayNeo diagnostic checklist exist; visual calibration patterns TODO. |
| 64 | Accessibility mode | PARTIAL | Reduce Motion support exists; scale/contrast/VoiceOver/focus navigation audit TODO. |
| 65 | Privacy screen/lock | PARTIAL | Privacy mode state exists; Face ID/local-auth lock UI TODO. |
| 66 | Desktop lock screen | TODO | LocalAuthentication-gated restore/reopen. |
| 67 | Low-distraction notifications | TODO | Kamihi-owned notification banners only. |
| 68 | Quick calculations/conversions | PARTIAL | Local calculator is implemented in the controller; unit/currency conversion commands TODO. |
| 69 | Clock/timer panel | PARTIAL | Clock exists; focus timer service exists; richer panel UI TODO. |
| 70 | Pomodoro/Focus timer | PARTIAL | 25-minute configurable timer engine exists; completion notification/presets TODO. |

## Newly discovered high-value features

| # | Feature | Status | Why it matters / next requirement |
|---:|---|---|---|
| 71 | Browser back/forward/reload controls | TODO | Makes external WebKit usable without relying on page navigation chrome. |
| 72 | Desktop browser address/search bar | TODO | Essential for arbitrary browsing from the phone controller. |
| 73 | Favorites + recent sites | TODO | One-tap workspace startup and faster glasses use. |
| 74 | Web app pinning | TODO | Pin ChatGPT/GitHub/YouTube/custom sites as Desktop apps. |
| 75 | Hardware keyboard shortcut layer | TODO | Cmd-K launcher, Cmd-W close, Cmd-Tab cycle, layout shortcuts where public APIs permit. |
| 76 | Trackpad tuning | TODO | Pointer sensitivity, acceleration curve, natural scrolling, drag lock and tap-to-click controls. |
| 77 | Drag-edge snap preview | TODO | Show target rectangle and snap automatically at screen edges/corners. |
| 78 | Continuous session autosave | TODO | Persist workspace after meaningful window/layout changes rather than only explicit/disconnect saves. |
| 79 | External-display health banner | TODO | Clear connected/reconnecting/display-lost states with recovery actions. |
| 80 | RayNeo safe-area calibration | TODO | User-adjustable overscan/safe margins and saved glasses profile. |
| 81 | Web app lifecycle sleeping | TODO | Freeze or unload long-idle/minimized WebViews to reduce heat and battery drain. |
| 82 | Document import center | TODO | Files picker, recent documents and security-scoped access. |
| 83 | Quick Paste to active app | TODO | Clipboard item -> focused web editor/AI input in one action. |
| 84 | Desktop capture/share | TODO | User-triggered screenshot and iOS share sheet. |
| 85 | Recovery snapshot | TODO | Save last known-good window/session configuration and offer restore after abnormal termination. |
| 86 | Connection quality HUD | TODO | Surface display/session health, host latency when remote mode is used, and actionable warnings. |
| 87 | Workspace template editor | TODO | Let user save custom window/app layouts beyond the built-in five presets. |
| 88 | Fullscreen app mode | TODO | One-command distraction-free fullscreen with quick return to previous layout. |
| 89 | Keyboard command cheat sheet | TODO | Discoverable list of active shortcuts and gesture equivalents. |
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

1. Make external-display input genuinely reliable: pointer, click, double click, drag, scroll, context click and keyboard focus.
2. Add browser navigation/address bar and hardware keyboard shortcuts.
3. Complete resize handles + drag-edge snapping + preview.
4. Add continuous autosave, reconnect health and recovery snapshot.
5. Add native Files/PDF, document import and desktop capture/share.
6. Add browser tabs/bookmarks/downloads/reader mode + WebView sleeping.
7. Add trackpad tuning, safe-area calibration and accessibility presets.
8. Integrate existing remote host/dev-project/dictation capabilities into desktop windows.
9. Finish polish, accessibility, RayNeo calibration and physical verification.
