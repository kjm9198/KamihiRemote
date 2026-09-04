# Kamihi Desktop — One Persistent iPhone Desktop Goal

## North Star

Kamihi Desktop is an **iPhone-powered desktop environment for RayNeo Air 4 Pro and normal external displays**. The product should feel like iOS/iPadOS expanded onto a desktop canvas: fast, simple, persistent, touch-secure, trackpad-first, and useful for normal daily computer work.

> Plug the iPhone into an external display, enter one desktop, and continue where you left off. There are no startup modes to choose and no Mac-remote product in the normal flow.

The user should not have to think about profiles, modes, layouts, or what kind of session they are starting. Kamihi is one computer-like desktop.

## Product direction — ONE DESKTOP

This is the canonical product goal from 2026-09-04 onward.

- **One persistent desktop only.** Remove the user-facing Clean Desktop, Resume, Work, Browse, Media and Vibe startup-profile chooser.
- Normal launch is a simple **Enter Desktop** flow.
- Enter Desktop restores the user's last desktop state automatically when state exists.
- A genuinely new/cleared desktop starts as a **plain black empty desktop**. Do not auto-open ChatGPT, YouTube, Browser, Notes, or other apps.
- Apps open only when the user explicitly launches them.
- Windows/tabs stay where the user left them when persistence is appropriate.
- Legacy startup-profile identifiers or migrations may remain internally only when required to avoid breaking existing user data. They must not shape the normal UI.
- **Remote for Mac is retired.** Do not expose, restore, market, or spend feature time on Mac-host pairing/networking/remote-control paths. Dormant compatibility code may remain only where deleting it would break existing data/build compatibility.
- Do not build a Mac host as part of Kamihi Desktop product work.

## Immediate usability priorities

Core computer behavior outranks novelty features.

1. **Deliberate window movement.** Ordinary pointer movement must never accidentally drag a window. Moving a window requires an intentional title-bar hold before movement (target roughly 1.5–2 seconds, tuned by testing), with clear armed feedback. Clicking/tapping normally remains a click.
2. **Reliable close/delete controls.** X/close must actually close the intended window or tab. Minimize/maximize/restore and tab close must have reliable software-pointer hit targets and correct focus ownership.
3. **Plain black desktop.** The empty desktop is black and uncluttered. No atmospheric wallpaper or pre-seeded windows.
4. **Real productivity apps.** Notes alone is insufficient. Add a capable **Documents** app for longer-form writing and a **Sheets** app for spreadsheet/table work, with Files integration and sensible import/export. Microsoft Word/Excel web apps may be optional launchable apps, but Kamihi must not depend on them for basic document/spreadsheet work.
5. **Browser migration without credential extraction.** Make it easy to bring user-controlled/exportable data such as bookmarks/favorites into Kamihi. Use public iOS/WebKit Password AutoFill, passkeys and normal authentication for credentials. Never scrape, copy, store, log, or attempt to bypass Safari/Chrome isolation for passwords, cookies, tokens, or raw logged-in sessions.
6. **Best daily apps, on demand.** Browser, ChatGPT, YouTube, Files, Photos, Documents, Sheets, Calculator, PDF, Clipboard and Settings form the core app set. They are launchable tools, not permanent desktop furniture.

## Readiness question

At the start of every improvement run ask:

> If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Identify the single biggest blocker to YES and address core readiness before novelty.

## Readiness gate

Kamihi Desktop is not software-ready until all software-testable items below are verified:

- External-display connection reliably enters the one desktop without Mac pairing or another computer.
- Enter Desktop restores prior state; a fresh/cleared session opens an empty black desktop.
- External canvas uses the full resolution/mode iOS actually negotiates, targets clean 16:9 1920×1080 where available, handles safe areas/overscan/reconnect, and never falsely claims it can force 120 Hz.
- Pointer is visible, high-contrast, precise and low-lag with sensible acceleration, isolated click/right-click/double-click/drag behavior, smooth momentum scrolling, and no idle rendering loop.
- Window movement requires deliberate intent rather than accidental pointer motion.
- iPhone controller is predominantly a full trackpad, with Keyboard and contextual controls reachable one-handed and no unnecessary permanent chrome.
- Windows can move, resize from all edges/corners, maximize/restore, snap halves/thirds/quarters with previews, place intelligently, close reliably, and participate in a stable overview/window-management model.
- Do not reintroduce user-facing workspace/profile complexity merely to satisfy an older roadmap item. One persistent desktop is the product model.
- Shell uses original Kamihi styling informed by iOS/iPadOS conventions: System/Light/Dark semantic styling where relevant, SF Symbols, readable 1080p typography, accessibility and no direct copying of macOS/Samsung proprietary trade dress. The desktop background itself defaults to plain black.
- Browser supports tabs, address/search, back/forward/reload, bookmarks/history, downloads, find/share, app pinning, session persistence and conservative WebView sleeping/memory handling. YouTube/ChatGPT must be usable as daily web apps.
- Phone Takeover/auth uses public iOS/WebKit APIs for Password AutoFill, passkeys, CAPTCHA, file picker and touch-only auth flows; raw credentials are never read/stored/logged.
- Native utilities are coherent enough for daily use: Documents, Sheets, Notes, Files/document picker, PDF, Photos permission flow, Calculator, Settings, clipboard/share/capture.
- Hardware keyboard shortcuts, VoiceOver, Dynamic Type on phone UI, Reduce Motion/Transparency, contrast, large pointer, error/empty/loading states and reconnect recovery are covered.
- Long 1080p sessions are responsible: inactive WebViews sleep/release, thermal/Low Power Mode behavior is sensible, memory is cleaned and unnecessary idle timers/display links are absent.

## RayNeo Air 4 Pro target

RayNeo Air 4 Pro is the first-class physical target. Normal 2D target is 1920×1080, 16:9. Kamihi must use the native backing resolution, scale and maximum refresh capability that iOS actually negotiates and exposes.

Do not artificially downscale a negotiated 1080p scene. Do not claim or force 120 Hz when iOS reports less. Do not fake HDR capability if the public external-display path does not safely expose it.

Track logical UIKit size separately from native pixels/scale, track `maximumFramesPerSecond`, preserve 16:9 without clipping, support persisted safe-area/overscan calibration, readable glasses text scaling, display diagnostics, and stable unplug/replug recovery without duplicate sessions.

## Trackpad and pointer quality gate

Required: precise one-finger movement; low-speed precision plus acceleration; two-finger scroll isolation; momentum/natural-scroll option; click/double-click/right-click correctness; deliberate hold-to-move window behavior; cancellation without leaked clicks; optional subtle haptics; useful cursor states; and no permanent idle 60/120 Hz rendering loop.

## Phone controller quality gate

The connected iPhone should feel predominantly like a **full-screen trackpad**. Keep Keyboard plus one More/context control readily available. Apps, windows, commands, settings, capture, Phone Takeover and other utilities belong behind contextual/on-demand surfaces until requested.

## Browser, migration and authentication

Browser is a real desktop app, not a decorative WebView. Preserve session continuity through supported WebKit mechanisms and user-controlled import paths.

Kamihi may import data that the user can legitimately export/select, such as bookmarks/favorites or files. It must not attempt to silently copy another browser's protected password database, cookies, authentication tokens or private app container data.

For login/form/CAPTCHA/file-picker/auth flows, use public Apple/WebKit mechanisms and Phone Takeover where touch/native OS services are required. Passwords/passkeys remain under iOS/WebKit control.

## Native productivity apps

Kamihi's native app goal includes:

- **Documents** — longer-form writing/editing, document persistence, Files integration and useful export/import.
- **Sheets** — spreadsheet/table editing suitable for everyday lightweight work, persistence, Files integration and useful export/import.
- Notes.
- Files/document picker.
- PDF viewer.
- Photos with correct permission flow.
- Calculator.
- Settings.
- Clipboard/share/capture.

These should feel like coherent iPad-class apps inside Kamihi windows, not generic developer pages.

## Performance and energy

Measure and improve pointer latency, Core Animation pacing, memory, WebKit process count, battery, thermal state and reconnect stability. Sleep/throttle minimized or long-idle WebViews conservatively without losing important state.

## Desktop Lab requirement

Desktop Lab remains mandatory for substantial UI/input changes. It should model a true 16:9 external screen plus live iPhone controller using the same DesktopSession. Use it to verify the **one-desktop flow**, empty black desktop, restore behavior, cursor, click, deliberate window drag, close controls, scroll, resize, snapping, overview, launcher, apps, browser flows, themes and animations before physical RayNeo testing.

## Mandatory failure triage / CI

At the start of every run:

1. Search Gmail for the newest GitHub Actions/GitHub CI failure emails related to `kjm9198/KamihiRemote`, including Run failed, Apple Build, Apple Integration Smoke/Desktop Simulator Smoke, legacy simulator-host-smoke names, build/deploy and the current main SHA.
2. Compare them with latest `main` SHA and exact GitHub Actions check-runs. Ignore stale failures from older SHAs after newer commits fixed them.
3. If current main has a failing check, inspect exact workflow/job/step/logs and fix it before product work unless definitively external/unrelated and documented.
4. After every push inspect Actions for that exact SHA.
5. Apple/Desktop simulator integration smoke must pass on the **first attempt**. Same-SHA attempt-1 failure followed by rerun success without a code change is a CI harness defect: inspect logs/artifacts and harden the harness. Never hide product/build/protocol failures with retries.
6. Preserve per-SHA non-cancelling workflow evidence and diagnostic artifacts.

## Quality rotation

Keep rotating major quality areas so work does not become one-dimensional, but the readiness audit overrides novelty and selects the highest-impact unfinished blocker inside the next area:

1. External-display/RayNeo fidelity.
2. iPadOS-style shell/design system.
3. Trackpad/pointer.
4. Windowing/window management.
5. Phone controller ergonomics.
6. Browser/web-app quality and migration.
7. Phone Takeover/authentication.
8. Native apps, especially Documents/Sheets.
9. Performance/energy/WebView lifecycle.
10. Keyboard/accessibility/final polish.

Do not restore startup profiles/workspace complexity just because older rotation notes mention them.

## Physical-only validation

These remain **NEEDS PHYSICAL TEST** until verified on a real iPhone + RayNeo Air 4 Pro/external monitor:

- actual negotiated resolution/refresh,
- overscan/readability in glasses,
- USB-C unplug/reconnect,
- end-to-end pointer latency and feel,
- deliberate hold-to-move window feel,
- Bluetooth keyboard/mouse,
- Password AutoFill/passkeys/CAPTCHA/file picker on real services,
- YouTube/ChatGPT login/playback,
- long-session battery/thermal behavior.

Even when every software gate is green, report **SOFTWARE-READY / NEEDS PHYSICAL VALIDATION** until those hardware checks are completed.