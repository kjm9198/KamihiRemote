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

Default structure stays approximately: compact status/header → large trackpad → small contextual bottom toolbar. Do not restore permanent Apps + Commands + Windows + Workspaces + URL + utility rows. Controls adapt to the active app.

## Browser and web apps

Browser is a real desktop app. Current foundation now includes retained per-tab WebViews, tab/session persistence, address/search, back/forward/reload/stop, bookmarks, history, and find-on-page. Remaining browser-cycle work includes downloads, share, app pinning, desktop/mobile preference where useful, tab overview polish, and conservative sleeping/recovery of inactive WebViews.

ChatGPT, YouTube and other web apps remain optional apps, not mandatory desktop furniture. Shared standalone web-app surfaces use the persistent default WebKit website data store for session continuity.

## Phone Takeover and authentication

Use the iPhone for interactions that need real touch/native OS services:

Desktop web app → Continue on iPhone → login/form/CAPTCHA/file picker/auth → Return to Desktop.

Prioritize public Apple/WebKit capabilities for Password AutoFill, passkeys, Face ID/device authentication, file/document picker, photo picker, and direct touch. Never read, store, or log raw passwords/credentials.

## Native apps

Notes, Files, PDF, Photos, Calculator, Settings, Clipboard and future utilities should feel like native iPad apps placed inside Kamihi windows, not generic pages inside fake chrome.

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
- **Next rotation focus: 7 — Phone Takeover/authentication.** Prioritize safe Continue-on-iPhone session continuity, Password AutoFill/passkey compatibility through public APIs, CAPTCHA/form/file-picker ergonomics, and never exposing raw credentials.

## Physical-only checks

Do not mark these verified based only on CI/Simulator:

- actual RayNeo 1920×1080 negotiation,
- actual negotiated refresh rate,
- perceived pointer latency,
- USB-C unplug/replug,
- glasses readability/overscan,
- HDR behavior,
- Password AutoFill/passkeys,
- ChatGPT/YouTube login/playback,
- Bluetooth keyboard/mouse behavior,
- long-session battery/thermal behavior.

## Definition of done

Kamihi is done when it feels like an intentional Apple-native desktop workflow rather than an app demo: desktop-first flexible launch, no normal Remote-for-Mac compartment, genuinely open-ended Clean Desktop, best RayNeo mode iOS negotiates, excellent pointer/scroll/drag, predictable fluid windows, usable desktop browser, native-feeling utilities, practical secure phone takeover, themes/accessibility, reconnect/session restore, sensible energy behavior, continuously green first-attempt CI, and completed physical RayNeo checks before claiming full hardware readiness.
