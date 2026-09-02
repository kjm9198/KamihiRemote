# Kamihi Desktop — iPhone OS-on-Display Goal

Current desktop-first baseline: `40aee5a` and newer.

## North Star

Kamihi is primarily an **iPhone-powered desktop environment for RayNeo Air 4 Pro and other external displays**. It should feel like iOS/iPadOS expanded onto a desktop canvas: native interaction patterns, Apple-like clarity, excellent pointer/trackpad behavior, real window productivity, secure phone handoff, and enough freedom to browse, watch media, write, work, organize files, use AI, or do anything else the built-in/public-API app set supports.

Vibe coding is an optional workflow, not the identity of the product.

> Connect the iPhone to RayNeo, choose how to start, and comfortably use Kamihi Desktop for an hour like a lightweight iPadOS-class computer without wishing the interface were Samsung DeX, a laptop, or the normal phone UI.

## Product direction

- The normal user-facing app must **not present Remote for Mac as a separate compartment/product**.
- Legacy Mac-remote code may remain dormant for regression/backward compatibility, but should not shape normal navigation or receive feature priority.
- Normal launch starts with desktop profiles: Clean Desktop, Resume, Work, Browse, Media, and optional Vibe.
- Profiles only choose the initial layout; once inside, all available desktop apps remain freely launchable and rearrangeable.
- Clean Desktop must remain genuinely blank/flexible.
- The iPhone is the secure control surface: trackpad, keyboard, launcher, contextual controls, Phone Takeover, authentication, file/photo picking.

## RayNeo Air 4 Pro target

RayNeo Air 4 Pro is the first-class physical display target. Normal 2D target is 1920×1080, 16:9, with hardware capability up to 120 Hz and HDR10. Kamihi must use the **native backing resolution, scale, and maximum refresh capability that iOS actually negotiates and exposes**.

Do not artificially downscale a negotiated 1080p scene. Do not claim or force 120 Hz when iOS reports less. Do not fake HDR capability if the public external-display path does not safely expose it.

Required display behavior:

- track logical UIKit size separately from native pixel size and native scale,
- track `maximumFramesPerSecond`,
- render using negotiated native backing scale,
- preserve 16:9 without clipping,
- persisted RayNeo safe-area/overscan calibration,
- readable glasses text scaling,
- display diagnostics showing native resolution + negotiated refresh,
- stable unplug/replug recovery with no duplicate sessions,
- full native scene size for Desktop Lab/reference screenshots.

Physical RayNeo resolution/refresh remains `NEEDS PHYSICAL TEST` until verified on the real iPhone + Air 4 Pro.

## iPadOS-style visual identity

Prefer system typography, SF Symbols, semantic colors, System/Light/Dark appearance, restrained materials, clear active-window hierarchy, comfortable spacing, accessible targets, contextual controls, and original Kamihi dock/window/pointer styling.

Avoid developer-dashboard UI, forced dark mode, permanent control walls, copied macOS traffic lights/Samsung trade dress, glass everywhere, tiny chrome, and layouts that assume every session is vibe coding.

## Trackpad and pointer quality gate

Required: precise one-finger movement; low-speed precision + acceleration; two-finger scroll isolation; momentum/natural-scroll option; click/double-click/drag-lock/right-click correctness; cancellation without leaked clicks; pointer/scroll tuning; optional subtle haptics; Kamihi Dot/Arrow/Precision/Accessibility cursors; click/drag/text/resize/busy cursor states; and no permanent idle 60/120 Hz rendering loop.

## Windowing quality gate

Required: drag; all-edge/corner resize; minimum sizes; correct z-order; halves/thirds/quarters; edge snap preview; maximize + true floating-frame restore; minimize/restore continuity; overview/Mission Control; useful workspaces; keyboard switching; intelligent placement; and spatially coherent animations.

## Phone controller quality gate

The normal connected controller is **trackpad-first to the point of feeling like a full-screen trackpad**. Keep only the always-needed Keyboard control plus one More/context control visible over the trackpad. Apps, windows, commands, settings, capture, Phone Takeover and other utilities stay behind contextual/on-demand surfaces until requested. Do not restore permanent preview panels, Apps + Commands + Windows + Workspaces + URL rows, or utility dashboards that reduce the usable trackpad area. The keyboard must reliably target the active desktop window and must never leak text to the wrong window after focus changes.

## Browser and web apps

Browser is a real desktop app. Current foundation now includes retained per-tab WebViews, tab/session persistence, address/search, back/forward/reload/stop, bookmarks, history, and find-on-page. Remaining browser-cycle work includes downloads, share, app pinning, desktop/mobile preference where useful, tab overview polish, and conservative sleeping/recovery of inactive WebViews.

ChatGPT, YouTube and other web apps remain optional apps, not mandatory desktop furniture. Shared standalone web-app surfaces use the persistent default WebKit website data store for session continuity.

## Phone Takeover and authentication

Use the iPhone for interactions that need real touch/native OS services:

Desktop web app → Continue on iPhone → login/form/CAPTCHA/file picker/auth → Return to Desktop.

Prioritize public Apple/WebKit capabilities for Password AutoFill, passkeys, Face ID/device authentication, file/document picker, photo picker, and direct touch. Never read, store, or log raw passwords/credentials.

Current takeover behavior uses a dedicated phone `WKWebView` backed by `WKWebsiteDataStore.default()` so login cookies/session state remain in WebKit instead of being copied through Kamihi. The phone flow handles OAuth/new-window links in the visible takeover, exposes touch-friendly back/forward/reload controls, and returns the final Browser URL to the active desktop tab so redirect-based authentication can resume on the external display. Real Password AutoFill/passkey/CAPTCHA/file-picker compatibility remains `NEEDS PHYSICAL TEST` on a device.

## Native apps

Notes, Files, PDF, Photos, Calculator, Settings, Clipboard and future utilities should feel like native iPad apps placed inside Kamihi windows, not generic pages inside fake chrome.

Files now uses the iOS document picker in copy mode and keeps user-selected copies inside Kamihi's Application Support container. PDFs render through PDFKit; other supported formats use Quick Look. Kamihi does not keep broad external filesystem access or raw credentials to support this workflow.

## Performance and energy

Measure and improve pointer latency, Core Animation pacing, memory, WebKit process count, battery, thermal state, and reconnect stability. Sleep/throttle minimized or long-idle WebViews conservatively without losing important state.

## Desktop Lab requirement

Desktop Lab remains mandatory for substantial UI/input changes and should model a true 16:9 external screen plus live iPhone controller using the same `DesktopSession`. Use it to verify cursor, click, scroll, drag, resize, snapping, overview, launcher, apps, themes, startup profiles, browser flows, and animations before physical RayNeo testing.

## CI requirement

Every coherent batch:

1. Search Gmail for the newest KamihiRemote GitHub failure email and match it to the exact SHA/workflow.
2. Inspect latest `main` and current GitHub Actions before editing.
3. If current head is red, diagnose/fix it before feature work.
4. Implement one focused rotation area.
5. Run the strongest available simulator/self-check/Desktop Lab/integration checks.
6. Push only a compiling/tested batch.
7. Inspect Actions for the exact pushed commit.
8. Apple Integration Smoke must pass on its **first attempt**. A fail-then-rerun-green identical SHA is a CI reliability defect, not healthy CI.
9. Preserve per-SHA smoke evidence and Apple Build transcripts so failure emails can be diagnosed from artifacts.
10. Update roadmap evidence after the run.

## Hourly rotation

1. RayNeo resolution/refresh/safe-area/reconnect.
2. iPadOS shell, themes and design system.
3. Trackpad and pointer.
4. Windowing and spatial animations.
5. Phone controller ergonomics.
6. Browser and web apps.
7. Phone Takeover/authentication.
8. Native desktop apps.
9. Performance/energy/WebView lifecycle.
10. Keyboard/accessibility/final polish.

Then repeat with the highest-impact unfinished issue in each category without duplicating prior work.

## Rotation evidence

- **2026-09-01 — Focus 1: RayNeo display fidelity.** Added persisted horizontal/vertical safe-area calibration, applied margins consistently to desktop coordinates, refreshed native metrics on display-mode changes, prevented duplicate session notifications, surfaced native resolution + negotiated refresh, and added RayNeo calibration/settings. Feature head `5b07ad3`; Apple Build + Integration Smoke passed first attempt. Physical resolution/refresh/overscan/readability/pointer latency/USB-C reconnect remain `NEEDS PHYSICAL TEST`.
- **2026-09-01 — Focus 2: iPadOS shell/themes.** Added persistent System/Light/Dark appearance, adaptive Kamihi wallpaper, theme-aware display/Desktop Lab surfaces, semantic overlays, adaptive translucent dock, and appearance settings. Feature head `6ae2808`; successor evidence head `c6c81f3` completed Apple Build/deploy/Integration Smoke, smoke first attempt.
- **2026-09-01 — Focus 3: Trackpad/pointer.** Added adaptive low-speed stabilization, bounded extreme acceleration, direct drag/resize movement, drag-lock drop without click leakage, hardened manipulation cleanup, and improved bounded momentum. Feature head `f000e5b`; Apple Build + Integration Smoke passed first attempt.
- **2026-09-01 — Focus 4: Windowing/spatial continuity.** Preserved floating frames across snap/maximize, unified drag-edge placement, restored snapped/maximized windows under the same pointer grab position, and detached snapped windows cleanly on manual resize. Feature head `6c87dcd`; subsequent evidence established the windowing line without a product rollback.
- **2026-09-01 — Focus 5: Phone controller ergonomics.** Reworked the bottom controller to stay trackpad-dominant, replaced text-heavy launcher chrome with compact controls, maintained 44×44 thumb targets, made app actions contextual, used semantic theme colors, improved Continue-on-iPhone affordance, and surfaced precision-mode accessibility state. Feature head `094ad81`; Apple Build, deploy, and Integration Smoke were green with smoke passing first attempt.
- **2026-09-01 — Focus 6: Browser/web-app quality.** Replaced the superficial single-WebView tab UI with retained per-tab `WKWebView` instances; persisted tabs/active tab/bookmarks/history across launches; wired real back/forward/reload/stop and address/search; added bookmark/history library and find-on-page; retained the default website data store for login/session continuity; and restored the shared standalone WebView bridge used by ChatGPT, YouTube and Phone Takeover. Initial browser heads exposed real compile regressions; Gmail failure triage plus newly persisted Apple Build transcripts identified and fixed each exact error rather than masking/retrying. Final feature/fix head `40aee5a`: iOS build passed, macOS host build passed, deploy passed, and Apple Integration Smoke passed on **attempt 1**. The Apple Build workflow now also preserves per-SHA iOS/macOS transcripts and no longer cancels an older SHA merely because a newer commit arrives.
- **2026-09-01 — Focus 7: Phone Takeover/authentication.** Rebuilt Continue-on-iPhone around an interactive phone WebView using the default persistent WebKit data store; added touch-friendly navigation/loading state; handled OAuth/`target=_blank` flows in the visible takeover rather than invisible windows; kept password/passkey values entirely inside WebKit/iOS; and synchronized the final Browser URL back to the active desktop tab on return. Feature head `a96e492`: Apple Build and deploy passed; Apple Integration Smoke was still running on attempt 1 when this evidence note was written. Real Password AutoFill/passkeys/CAPTCHA/file-picker behavior remains `NEEDS PHYSICAL TEST` on a device.
- **2026-09-01 — Focus 8: Native desktop apps.** Hardened Files into a persistent, sandbox-backed document library using the public iOS document picker in copy mode; imported documents survive relaunch/reconnect inside Kamihi's Application Support container; duplicate names are preserved safely; removing a document only deletes Kamihi's owned copy; PDFs now use a native PDFKit continuous-page viewer while other supported formats retain Quick Look. Feature head `678cf9c`; Apple Build and Apple Integration Smoke passed on **attempt 1**, with smoke evidence uploaded. Real document-provider behavior and PDF interaction on the iPhone + external display remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 4 (current cycle): Window resize affordances.** Replaced the single bottom-right resize hint with eight lightweight active-window affordances covering all four edges and four corners. The marker for the edge/corner currently targeted by the shared DesktopSession cursor becomes stronger, while resize gesture ownership stays on the iPhone controller and maximized windows stay visually clean. Feature head `6be9289`; Apple Build and Apple Integration Smoke passed on attempt 1. Physical resize feel on iPhone + RayNeo remains `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 5 (current cycle): Phone controller ergonomics.** Adapted the contextual controller rail for narrow iPhones: the full app toolbar remains on wider phones, while constrained layouts collapse app-specific Browser/YouTube/ChatGPT/Notes actions into one contextual menu without shrinking the large trackpad. Keyboard, app switching, Precision Mode and commands remain directly thumb-accessible with 44 pt primary targets. Feature head `d2857f8`; Apple Build, deploy and Apple Integration Smoke all passed on **attempt 1**.
- **2026-09-02 — Focus 6 (current cycle): Browser/WebView lifecycle.** Replaced unbounded retained-tab WebView growth with a six-WebView most-recently-used warm pool. Inactive least-recent WebViews are stopped and released once the pool exceeds the cap; persistent tab URL/title metadata remains in `DesktopBrowserState`, and cookies/login/session data remain in `WKWebsiteDataStore.default()` rather than being copied through Kamihi. Re-selecting an evicted tab recreates its WebView from persisted tab state. Feature head `6917d68`; Apple Build, Pages, and Apple Integration Smoke all passed on **attempt 1**, including smoke evidence upload. Long-session memory/process-count benefit and real site session restoration remain `NEEDS PHYSICAL TEST`/device profiling.
- **2026-09-02 — Focus 7 (current cycle): Phone Takeover/authentication.** Non-web OAuth/SSO custom URL schemes encountered inside the takeover WebView can now hand off to installed iOS apps through public `UIApplication.open`, while normal HTTP(S) and WebKit-owned navigation stay inside the visible secure takeover. Kamihi does not inspect, copy, log or persist passwords, passkeys, tokens or form values. Feature head `51f03723`; Apple Build, Pages and Apple Integration Smoke all passed on **attempt 1**. Provider-specific app handoff, Password AutoFill/passkeys, CAPTCHA/file picker and ChatGPT/YouTube login remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 8 (current cycle): Native desktop apps.** Added user-triggered external-desktop capture/share from the phone controller. Kamihi captures only its external-display `UIWindow` at the iOS-negotiated backing scale and presents the standard iPhone share sheet without automatic Photos saving or broad photo-library access. Feature head `5a581dfb`; Apple Build, Pages and Apple Integration Smoke all passed on **attempt 1**. Real RayNeo capture sharpness, WebKit/video capture fidelity and share-sheet behavior remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 9 (current cycle): Performance/energy.** External Desktop now observes live Low Power Mode and thermal pressure and suppresses purely decorative launcher/snap motion plus expensive launcher shadow work under conservation pressure while keeping pointer, window manipulation and WebKit interaction responsive. Feature head `2fe7600`; successor evidence head `cb9eb394` is green across Apple Build, Pages and Apple Integration Smoke, smoke first attempt. Physical battery/thermal benefit remains `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 10 (current cycle): Keyboard/accessibility/polish.** Added a discoverable Keyboard & Gestures guide with Dynamic Type and cleaner VoiceOver command-row semantics, covering the actual phone trackpad gestures, window cycling, keyboard entry, Precision Mode and Continue-on-iPhone flow without advertising unverified hardware shortcuts. Feature head `ebd5b3d`; Apple Build, Pages and Apple Integration Smoke passed, smoke first attempt. Hardware-keyboard bindings and real VoiceOver/Dynamic Type feel remain device follow-up.
- **2026-09-02 — Focus 1 (current cycle): RayNeo display fidelity.** Added the high-contrast on-canvas display calibration guide with physical outer border, corner marks, quarter/center grid, persisted safe-frame outline and exact iOS-reported resolution/maximum refresh ceiling. Feature head `d424f2a`; Apple Build, Pages and Apple Integration Smoke passed on **attempt 1**. Real RayNeo 1920×1080 negotiation, refresh, overscan/readability and USB-C reconnect remain `NEEDS PHYSICAL TEST`.
- **2026-09-02 — Focus 2 (current cycle): iPadOS shell/design system.** Aligned the external-display dock with the shared semantic Kamihi shell: System/Light/Dark-compatible semantic surfaces, transparency-aware presentation, SF Symbols, accessible control sizing, clearer running/active state and display status. The full-trackpad phone controller remained untouched. Feature head `52255de`; Apple Build, Pages and Apple Integration Smoke all passed on **attempt 1**.
- **2026-09-02 — Focus 3 (current cycle, latest): Trackpad/pointer.** Retuned only the stock Balanced full-screen-trackpad profile from sensitivity/acceleration `1.20/1.00` to `1.12/0.82`, reducing low-speed overshoot while preserving the existing velocity acceleration and adaptive smoothing. A versioned migration applies only when persisted values are still the old stock defaults; any custom pointer tuning is preserved exactly. Feature head `d270fc5`; Pages, Apple Build and Apple Integration Smoke all passed on **attempt 1**, including the simulator-host smoke and evidence upload. The Desktop Lab artifact was visually inspected: the 1920×1080 external canvas/calibration remains intact and the phone controller is still the simplified full-trackpad surface with only Keyboard and More. Real pointer latency and the final Balanced feel on iPhone + RayNeo remain `NEEDS PHYSICAL TEST`.
- **Next rotation focus: 4 — Windowing and spatial animations.** Preserve the full-trackpad controller and choose the highest-impact unfinished windowing issue without repeating the existing eight-edge resize affordances or drag-edge snap-preview work.

## Physical-only checks

Do not mark these verified based only on CI/Simulator:

- actual RayNeo 1920×1080 negotiation,
- actual negotiated refresh rate,
- perceived pointer latency and final Balanced-profile feel,
- USB-C unplug/replug,
- glasses readability/overscan,
- HDR behavior,
- Password AutoFill/passkeys,
- ChatGPT/YouTube login/playback,
- Bluetooth keyboard/mouse behavior,
- native document-provider/PDF interaction on the external display,
- desktop capture fidelity for WebKit/video content,
- long-session battery/thermal behavior.

## Definition of done

Kamihi is done when it feels like an intentional Apple-native desktop workflow rather than an app demo: desktop-first flexible launch, no normal Remote-for-Mac compartment, genuinely open-ended Clean Desktop, best RayNeo mode iOS negotiates, excellent pointer/scroll/drag, predictable fluid windows, usable desktop browser, native-feeling utilities, practical secure phone takeover, themes/accessibility, reconnect/session restore, sensible energy behavior, continuously green first-attempt CI, and completed physical RayNeo checks before claiming full hardware readiness.
