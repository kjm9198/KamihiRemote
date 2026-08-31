# Kamihi Desktop — Native OS Experience Goal

Baseline: `09000c0` (Remote for Mac and Kamihi Desktop separated, Mode Chooser, TrackpadEngine, Desktop Lab, windowing, pointer styles, Phone Takeover, native Notes/Files foundation).

## North Star

Kamihi Desktop should feel less like a custom app pretending to be a computer and more like an **iPadOS-native desktop environment with Mac-class productivity**.

The practical target is:

> Connect an iPhone to RayNeo or another external display, choose Kamihi Desktop, and comfortably work for an hour using the iPhone as the control surface without wishing for Samsung DeX, a laptop, or the normal iPhone UI.

This is now a **quality-first goal**, not a feature-count goal.

## Product identity

- Keep **Remote for Mac** and **Kamihi Desktop** completely separated at the product/UI level.
- Keep the Mode Chooser as the deliberate entry point.
- Shared low-level services are fine; shared cluttered navigation is not.
- Kamihi Desktop should visually feel closer to iPadOS/windowed Apple UI than Windows, Samsung DeX, or a developer dashboard.
- Use original Kamihi styling and public Apple APIs only.

## Design target

Prioritize:

1. iPadOS-like spatial clarity.
2. Mac-like window productivity.
3. Apple-quality pointer and gesture behavior.
4. Contextual controls instead of permanent toolbars.
5. System typography, SF Symbols, semantic colors, materials and modern iOS visual hierarchy.
6. Light / Dark / System themes.
7. Smooth spring-based motion with spatial continuity.
8. Reduce Motion, Reduce Transparency, Increase Contrast and large-pointer support.

Avoid:

- dashboard-like phone UI,
- tiny controls,
- permanent rows of advanced actions,
- random floating windows,
- Windows/Samsung visual imitation,
- excessive blur/glass,
- fake OS controls that do not behave correctly.

## Highest-priority quality gates

### 1. Trackpad must become excellent

Treat the trackpad as the most important feature in the product.

Required end state:

- precise 1-finger pointer movement,
- velocity acceleration without jumpiness,
- low-speed precision,
- no pointer drift while 2-finger scrolling,
- smooth scroll momentum,
- correct tap / double-click / drag / drag-lock behavior,
- reliable 2-finger right-click,
- configurable pointer speed,
- configurable scroll speed,
- Natural Scrolling option,
- haptic feedback where useful,
- gesture cancellation rules that prevent accidental clicks,
- low perceived latency.

Desktop Lab must be used to visually verify this locally.

### 2. Cursor must feel native but distinctly Kamihi

Default should be the Kamihi Dot system.

Support interaction states:

- pointer,
- clickable/hover,
- pressed,
- dragging,
- text/I-beam where detectable,
- resize,
- busy/progress.

Animation must be subtle and fast. Cursor movement must never feel delayed by visual smoothing.

### 3. Windowing must feel spatial and predictable

Required:

- direct drag,
- direct corner/edge resize,
- minimum sizes,
- active/inactive state,
- correct z-order,
- half / third / quarter snapping,
- edge snap preview,
- maximize and restore preserving previous frame,
- meaningful minimize animation toward the dock,
- Mission Control / Window Overview,
- keyboard window switching,
- intelligent initial placement so new windows do not randomly cover the primary workspace.

### 4. Phone controller must remain contextual

Default layout should stay approximately:

1. compact status/header,
2. large trackpad,
3. small contextual bottom toolbar.

Do not reintroduce permanent Apps + Commands + Windows + Workspaces + URL + utilities + status controls on one screen.

The toolbar should adapt to the active app.

### 5. Phone Takeover must become a first-class workflow

This is the solution for interactions that are much better on the iPhone.

Prioritize:

- login,
- Password AutoFill,
- passkeys where WebKit/public APIs support them,
- Face ID/authentication flows,
- CAPTCHA,
- forms,
- file/document picker,
- camera/photo picker,
- direct touch web interaction.

Never read, log or manually store user passwords.

The ideal flow is:

Desktop web app → Continue on iPhone → finish interaction → Return to Desktop with session preserved.

### 6. Browser must become a real desktop application

Move browser controls into browser/window context instead of permanently occupying the phone UI.

Complete:

- address/search,
- tabs,
- tab overview,
- back/forward,
- reload/stop,
- bookmarks/favorites,
- history,
- downloads,
- find on page,
- share,
- open/continue on iPhone,
- desktop/mobile preference when appropriate,
- session persistence,
- minimized/inactive lifecycle management.

### 7. Native apps should feel like iPad apps

Notes, Files, PDF, Photos, Calculator and Settings should use native Apple frameworks and interaction patterns wherever possible.

They should not look like web pages placed inside fake desktop windows.

### 8. Themes must be coherent

Support:

- System,
- Light,
- Dark.

Create centralized design tokens for:

- desktop background,
- window surfaces,
- navigation material,
- text levels,
- strokes,
- shadows,
- spacing,
- radii,
- animation timing.

Do not scatter arbitrary hardcoded black/white/gray values through views.

### 9. iOS 27 and external-display lifecycle

Use the current public iOS external-display APIs and keep availability-gated compatibility where practical.

The app must correctly handle:

- Desktop selected with no display,
- external display connected after mode selection,
- external display already connected,
- disconnect,
- reconnect,
- app background/foreground,
- orientation changes,
- session restore,
- duplicate scene/lifecycle events.

RayNeo Air 4 Pro remains a first-class physical target.

### 10. Performance must be measured, not assumed

Use local Xcode/Instruments testing where available.

Watch:

- input latency,
- Core Animation frame pacing,
- memory,
- WebKit process count,
- Energy Log,
- thermal state,
- unnecessary timers/display links.

High-frequency cursor rendering should run only while interaction requires it.

Inactive/minimized WebViews should reduce work conservatively without destroying important user state.

## Local Desktop Lab requirement

Desktop Lab is mandatory for every substantial Desktop UI/input batch.

It should let an agent test on a Mac/iOS Simulator without RayNeo:

- mode routing,
- phone controller,
- cursor,
- click,
- scroll,
- drag,
- resize,
- snapping,
- Mission Control,
- launcher,
- browser navigation,
- workspace transitions,
- animations,
- theme changes,
- accessibility settings.

Capture screenshots when UI changes materially and inspect them rather than merely generating them.

## Verification requirement

Every coherent batch must run the strongest available checks:

1. iOS Simulator build.
2. macOS Host build when shared/remote code is affected.
3. `bash scripts/apple-integration-smoke.sh` when applicable.
4. Deterministic self-checks/unit-testable state logic.
5. Desktop Lab manual/screenshot review for UI/input changes.
6. GitHub Actions confirmation after push.

Physical-only items remain explicitly unverified until tested on real hardware:

- iPhone external-display connection,
- RayNeo Air 4 Pro resolution/readability,
- real pointer latency perception,
- real Password AutoFill/passkeys,
- ChatGPT authentication,
- YouTube playback,
- Bluetooth keyboard/mouse behavior,
- cable disconnect/reconnect,
- battery and thermal behavior.

## Priority order from baseline 09000c0

1. Trackpad physics + gesture-state reliability + pointer polish.
2. Direct resize handles + edge snapping + snap preview + restore-frame behavior.
3. Simplify/contextualize the phone controller further.
4. Full browser tabs/bookmarks/history/downloads + browser-context controls.
5. Harden Phone Takeover, authentication/session continuity and Open on iPhone handoff.
6. Centralized iPadOS-like design system + System/Light/Dark themes.
7. Native Files/PDF/Photos/Settings polish.
8. Hardware keyboard command routing + shortcut cheat sheet.
9. WebView sleeping, battery/thermal optimizations and profiling.
10. RayNeo safe-area calibration + physical verification.

## Definition of done

Do not declare this goal complete just because the features exist.

It is complete when the product feels coherent and comfortable:

- Mode Chooser is clean and obvious.
- Remote for Mac feels like its own polished native app.
- Kamihi Desktop feels like its own polished iPadOS-class environment.
- Phone controller is simple and contextual.
- Cursor movement feels excellent.
- Scrolling feels excellent.
- Clicking/dragging does not misfire.
- Windows move, resize, snap, minimize and restore naturally.
- Browser can be used as an actual desktop browser.
- Login/password/passkey workflows use Phone Takeover/native OS capabilities safely.
- Built-in utilities feel native.
- animations are smooth but not excessive.
- themes and accessibility behave correctly.
- reconnect/session restoration is reliable.
- CI is green.
- Remote-for-Mac regressions are absent.
- physical RayNeo-only checks are completed before claiming full hardware readiness.

The benchmark is not "does it work?"

The benchmark is:

> "Does this feel like an Apple-designed iPadOS desktop workflow that I would willingly use instead of carrying a laptop?"
