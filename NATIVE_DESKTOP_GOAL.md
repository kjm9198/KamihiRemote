# Kamihi Desktop — iPhone OS-on-Display Goal

Current desktop-first baseline: `141dadb` and newer.

## North Star

Kamihi is now primarily an **iPhone-powered desktop environment for RayNeo Air 4 Pro and other external displays**.

The product should feel like iOS/iPadOS expanded onto a large desktop canvas: native interaction patterns, Apple-like clarity, excellent pointer/trackpad behavior, real window productivity, secure phone handoff, and enough freedom that the user can browse, watch media, write, work, organize files, use AI, or do anything else the built-in/public-API app set supports.

Vibe coding is an optional workflow, not the identity of the product.

The benchmark is:

> Connect the iPhone to RayNeo, choose how to start, and comfortably use Kamihi Desktop for an hour like a lightweight iPadOS-class computer without wishing the interface were Samsung DeX, a laptop, or the normal phone UI.

## Product direction

- The **normal user-facing app no longer presents Remote for Mac as a separate compartment/product**.
- Legacy Mac-remote code may remain dormant for regression testing/backward compatibility, but it should not shape normal navigation or receive feature priority.
- Normal launch starts with Kamihi Desktop profiles: Clean Desktop, Resume, Work, Browse, Media, and optional Vibe.
- Startup profiles only choose the initial layout. Once inside, every available Kamihi Desktop app remains launchable and windows remain freely rearrangeable.
- Clean Desktop must be a true blank/flexible desktop, not a forced ChatGPT + YouTube layout.
- The iPhone is the secure control surface: trackpad, keyboard, launcher, contextual controls, Phone Takeover, authentication and file/photo picking.

## RayNeo Air 4 Pro target

RayNeo Air 4 Pro is the first-class physical display target.

Official hardware target for normal 2D desktop use:

- Full HD 1920×1080 per 2D display input.
- 16:9 desktop composition.
- Up to 120 Hz hardware refresh capability.
- HDR10-capable display hardware.

Kamihi must use the **native backing resolution, scale and maximum refresh capability that iOS actually negotiates and exposes** for the connected external screen.

Do not artificially downscale a 1080p external scene.
Do not claim or force 120 Hz when iOS reports a lower negotiated maximum.
Do not fake HDR capability if the public iOS external-display path does not expose a safe supported way to request it.

Required display work:

- track logical UIKit size separately from native pixel size,
- track native scale,
- track `maximumFramesPerSecond`,
- render the external scene at the screen's negotiated native backing scale,
- preserve 16:9 layouts without clipping,
- RayNeo safe-area/overscan calibration,
- readable text-size presets for glasses,
- display diagnostics showing native resolution + negotiated refresh,
- stable unplug/replug recovery,
- no duplicate desktop sessions on reconnect,
- use full native scene size for Desktop Lab/reference screenshots.

Physical RayNeo resolution/refresh remains `NEEDS PHYSICAL TEST` until the real iPhone + Air 4 Pro reports and displays it correctly.

## iPadOS-style visual identity

Kamihi Desktop should feel closer to iPadOS windowed multitasking than to Windows, Samsung DeX, or a fake macOS skin.

Use:

- system typography,
- SF Symbols,
- semantic colors,
- System / Light / Dark themes,
- materials only where appropriate,
- clear active/inactive window hierarchy,
- comfortable spacing,
- touch/pointer targets that remain easy to acquire,
- contextual controls,
- original Kamihi pointer/dock/window styling.

Avoid:

- developer-dashboard UI,
- forced dark mode,
- permanent walls of controls,
- copying macOS traffic lights or Samsung trade dress,
- glass on every surface,
- tiny desktop chrome,
- layouts that assume every session is vibe coding.

## Trackpad and pointer quality gate

The phone trackpad is one of the most important features.

Required end state:

- precise one-finger pointer movement,
- low-speed precision and velocity acceleration,
- no pointer movement during two-finger scrolling,
- momentum scrolling,
- natural scrolling option,
- tap/click/double-click correctness,
- hold/drag and drag-lock,
- reliable right-click,
- gesture cancellation that prevents accidental clicks,
- configurable pointer and scroll speed,
- subtle optional haptics,
- Kamihi Dot / Arrow / Precision / Accessibility cursor options,
- correct click/drag/text/resize/busy pointer states,
- high-refresh cursor updates only while interaction requires them,
- no permanent idle 60/120 Hz loop.

## Windowing quality gate

Required:

- drag,
- resize from edges/corners,
- minimum sizes,
- correct z-order,
- halves / thirds / quarters,
- edge snap preview,
- maximize + restore previous frame,
- minimize/restore spatial continuity,
- Mission Control/window overview,
- multiple workspaces when useful,
- keyboard window switching,
- intelligent new-window placement.

## Phone controller quality gate

Default controller remains approximately:

1. compact status/header,
2. large trackpad,
3. small contextual bottom toolbar.

Do not restore permanent Apps + Commands + Windows + Workspaces + URL + utility rows.

Controls adapt to the active app.

## Browser and web apps

Browser must become a real desktop app with tabs, tab overview, address/search, back/forward, reload, bookmarks, history, downloads, find, share, app pinning, desktop/mobile preference where appropriate, session persistence and efficient sleeping of inactive WebViews.

ChatGPT, YouTube and other web apps are apps the user can open when wanted; they are not mandatory desktop furniture.

## Phone Takeover and authentication

Use the iPhone for interactions that need real touch/native OS services:

Desktop web app → Continue on iPhone → login/form/CAPTCHA/file picker/auth → Return to Desktop.

Prioritize public Apple/WebKit capabilities for:

- Password AutoFill,
- passkeys,
- Face ID/device authentication,
- file/document picker,
- photo picker,
- direct touch interaction.

Never read, store or log raw passwords/credentials.

## Native apps

Notes, Files, PDF, Photos, Calculator, Settings, Clipboard and future utilities should feel like native iPad apps placed inside Kamihi windows, not generic web pages inside fake chrome.

## Performance and energy

Measure and improve:

- pointer latency,
- Core Animation frame pacing,
- memory,
- WebKit process count,
- battery usage,
- thermal state,
- reconnect stability.

Sleep/throttle minimized or long-idle WebViews conservatively without losing important user state.

## Desktop Lab requirement

Desktop Lab remains mandatory for substantial UI/input changes and should model a true 16:9 external screen plus the live iPhone controller using the same `DesktopSession`.

Use it to verify cursor, click, scroll, drag, resize, snapping, overview, launcher, apps, themes, startup profiles and animations before physical RayNeo testing.

## CI requirement

Every coherent batch:

1. Inspect latest main and current GitHub Actions before editing.
2. Implement one focused quality area.
3. Run the strongest available simulator/self-check/Desktop Lab/integration checks.
4. Push only a compiling/tested batch.
5. Inspect GitHub Actions for the exact pushed commit.
6. If CI fails, diagnose and fix it before starting a different area.
7. Update roadmap evidence.

## Hourly rotation

Each hourly improvement run must focus on a different area from the previous run:

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

- **2026-09-01 — Focus 1: RayNeo display fidelity.** Added persisted horizontal/vertical safe-area calibration, applied those margins consistently to the desktop coordinate space, refreshed native metrics on external display mode changes, prevented duplicate connect/disconnect session notifications, surfaced native resolution + negotiated maximum refresh on the iPhone controller, and added a RayNeo calibration/settings sheet. Exact feature head: `5b07ad3`. Apple build and Apple Integration Smoke both passed on the first attempt for that head. Physical Air 4 Pro resolution, actual refresh, overscan/readability, pointer latency, and USB-C reconnect remain `NEEDS PHYSICAL TEST`.
- **Next rotation focus: 2 — iPadOS shell, themes and design system.**

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

The goal is done when Kamihi feels like an intentional Apple-native desktop workflow rather than an app demo:

- launch is desktop-first and flexible,
- no normal Remote-for-Mac compartment,
- Clean Desktop is genuinely open-ended,
- RayNeo uses the best external-display mode iOS negotiates,
- pointer/scroll/drag feel excellent,
- windows are predictable and fluid,
- browser is usable as a desktop browser,
- native utilities feel like iPad apps,
- phone takeover makes authentication/forms practical,
- themes/accessibility work,
- reconnect/session restore works,
- energy use is sensible,
- CI stays green,
- physical RayNeo checks are completed before claiming full hardware readiness.
