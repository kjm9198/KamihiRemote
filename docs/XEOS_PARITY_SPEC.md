# Kamihi Desktop: external-display parity specification

Research and source audit: 2026-09-01. Baseline: `286dcbd8bf3ae4c3962a05d7b8bae29d0441ef75`.

## Goal and scope

Build a complete, independently implemented iPhone-powered desktop using the public behavior of XeOS as a product reference. Keep Kamihi branding, original interface assets and public Apple APIs. This is a native iOS application with an app-owned window manager. It is not macOS, a macOS emulator, or a way to run arbitrary installed iOS applications on another screen.

No published source repository for the referenced iPhone app was found in the site and source searches. Downloading its marketing HTML does not obtain its Swift application. The unrelated `macmade/XEOS` operating-system project must not be used as though it were this app. No XeOS source or assets were imported.

Evidence: the public website and guides were inspected; the XeOS binary was not installed or runtime-tested. The comparison below describes documented capabilities, not independently verified performance. Kamihi statuses are based on source inspection, with CI evidence recorded separately. An icon, stub, successfully compiled view or screenshot is not proof that a feature works with the external-display pointer.

## Source references

- [Product overview and FAQ](https://externaldisplayiphone.com/)
- [Connection and setup](https://externaldisplayiphone.com/guides/connect-iphone-ipad-to-monitor-or-tv)
- [Files and external locations](https://externaldisplayiphone.com/guides/mount-icloud-local-and-external-drives)
- [Phone layout handoff](https://externaldisplayiphone.com/guides/device-layout-mode)
- [Mouse, keyboard and shortcuts](https://externaldisplayiphone.com/guides/mouse-keyboard-and-shortcuts)
- [Photos and slideshows](https://externaldisplayiphone.com/guides/photo-slideshow-on-tv)
- [Guide directory: browser, installed sites, import and presenting](https://externaldisplayiphone.com/guides)

## Immediate source findings

1. First launch previously opened profile selection directly. This change adds a six-stage setup guide, saved progress, deferral, replay, accessory-status reporting and keyboard practice.
2. Display dimensions were initialized to 1920×1080 even when disconnected. Previously the settings page could present these defaults as output. This change hides hardware metrics until connected and labels the exposed refresh value as a maximum capability.
3. The external canvas renders Browser, ChatGPT, YouTube, Notes and Files. Its default branch only draws an app title. Launcher entries such as Photos, PDF Viewer, Calculator, Clipboard and Display Diagnostics therefore do not establish working native desktop apps. Some corresponding phone utilities exist elsewhere. Resolve these routes before claiming full app coverage.
4. The external scene is non-interactive. The software cursor sends JavaScript events to WebViews. Native Files, PDFKit and other SwiftUI controls require their own command routing or a phone control surface. Pointer movement over a native button does not activate that button automatically. This is a P0 functional gap, not merely visual polish.
5. Phone takeover currently creates a separate WebView with the default persistent data store. Cookies can be shared, but this does not preserve the original page's complete DOM, unsaved form text, back-forward list or scroll state. Do not claim seamless no-reload handoff.
6. The newer external canvas does not consume the `DesktopFeatureState.uiScale` preference that is used by an older canvas. A saved slider value alone is not working desktop scaling.
7. The README and parts of `desktop_roadmap.md` lag behind source. This document identifies audited gaps; older VERIFIED labels do not override the physical-test requirements.

## Setup behavior implemented in this change

| Step | Behavior | Acceptance |
|---|---|---|
| Welcome | Explains the app-owned desktop and optional accessories | No Mac pairing, account creation or permission prompt |
| Connect | Cable/adapter guidance; live external-scene state; troubleshooting | Disconnected users can continue; no fabricated resolution |
| Input | Phone gestures, optional Bluetooth instructions, iOS accessory reports, disposable typing field and pointer presets | Accessory detection is not labeled an end-to-end test; text is not stored |
| Screen fit | Real connected metrics, calibration overlay, safe margins and theme | Disconnect/background/dismissal removes the overlay; no hardware mode is forced |
| Phone interaction | Explains native touch, password manager and file-picker handoff | No credential import or broad permission request |
| Start | Existing Clean/Resume/Work/Browse/Media/Vibe choices | Completion is persisted only after finishing; no connection test is implied |

Back and Continue preserve position. Set up later defers only for this launch and leaves saved progress incomplete. Completed users return to the profile chooser. Review from the chooser or Desktop & Display preserves completion and app data. Debug screenshot fixtures neither complete setup nor save their step. The guide uses scrolling content, semantic colors, Dynamic Type, accessibility headings, Reduce Motion and controls at least 44pt high.

## Full feature coverage and acceptance contracts

Status: **present** = source path exists, still requires applicable runtime/device checks; **partial** = incomplete behavior; **missing** = no complete source implementation found. Every row is required unless a deliberate platform/security alternative is stated.

### Display and shell

The reference documents an independent external desktop, automatic detection, a resolution picker, content scaling and optional phone control. Its setup instructions include wired and AirPlay connections. Source: connection guide above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| D01 | External scene and full canvas | Present: scene delegate and coordinator | Real iPhone + RayNeo: connect before/after launch; inspect all edges |
| D02 | Display modes | Partial: negotiated metrics only; no selection | Enumerate only public supported modes; change safely; confirm actual geometry; recover from rejection |
| D03 | Content scale | Partial: preference not wired to active canvas | Apply to layout and input transforms together; verify all scale settings at all corners |
| D04 | Safe-area calibration | Present; new visual guide | Persist margins; no stretched content; no input/render offset |
| D05 | Reconnect and restore | Partial: restoration exists; launch profiles can replace state | Unplug with open tabs/files; reconnect without duplicates, lost edits or unexpected clean layout |
| D06 | Themes, wallpaper, contrast | Partial: semantic themes exist | System/light/dark, Reduce Transparency, custom wallpaper and accessible contrast |
| D07 | Lock and privacy | Partial: authentication service exists | Verify lock is enforced by the active canvas and all interaction routes |
| D08 | Status and quick settings | Partial: several controls exist in older surfaces | Connect settings to the active shell; do not expose no-op preferences |

### Windows and input

The reference documents draggable/resizable windows, snapping, overview, saved layout, software trackpad and hardware accessories. It also exposes keyboard commands for tabs and window switching. Source: mouse/keyboard guide above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| W01 | Move, all-edge/corner resize, z-order | Present mechanisms; runtime pending | Overlapping windows, minimum sizes and every edge on 16:9 and resized scenes |
| W02 | Snap and floating-frame restore | Present mechanisms | Halves/thirds/quarters; undo maximize/snap restores correct geometry |
| W03 | Minimize, overview, window cycling | Present/partial | Correct focus after close/minimize; hidden views release resources appropriately |
| W04 | True fullscreen | Missing in active shell | Hide dock/title/browser chrome; Escape and phone control restore original frame |
| W05 | Multiple instances/workspaces | Partial presets only | Independent browser/app windows and persistent named workspaces |
| I01 | Trackpad click, scroll, drag, right-click | Present mechanisms | Slow/fast movement, cancellation, drag lock, two-finger isolation, momentum |
| I02 | Bluetooth mouse and keyboard | Partial | Test pointer routing, wheel, right-click, typing, modifiers and reconnect on hardware |
| I03 | Shortcut dispatcher and help | Partial | Resolve app/window focus; shortcuts operate once; discoverable accessible help |
| I04 | Native-app command routing | Missing complete path | Phone/software pointer selects a Files row, scrolls a PDF, edits Notes and presses Calculator keys |
| I05 | Dictation to active field | Partial legacy infrastructure | User-triggered permission; preview/cancel; correct focused target; no unrelated text submission |

### Browser and installable sites

The reference's browser guide lists tabs, bookmarks, downloads, reader/reading list, find, site zoom, desktop/mobile mode, site-data clearing and saved sessions. The installed-sites guide describes named site shortcuts with their own windows and dock entries. See the guide directory above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| B01 | Tabs, URL/search, navigation, history | Present | New/close/switch/relaunch tabs; retained history and expected URL |
| B02 | Bookmark folders/import/export | Partial flat bookmarks | Parse supported bookmark exports; retain folders; additive import with duplicates handled |
| B03 | Download manager | Missing | WKDownload delegate, progress/cancel, collision-safe names, sandbox destination, retry and failed transfer cleanup |
| B04 | Install site as app and dock pin | Missing | Validated http(s) URL, editable title, persistent app ID/icon, own window, uninstall shortcut without deleting login data |
| B05 | Reading mode and reading list | Missing | Graceful unsupported page; restore original; save references; label offline availability accurately |
| B06 | Per-site zoom and mobile/desktop mode | Missing complete path | Zoom persists per origin, input coordinates stay aligned, no fictitious browser capability |
| B07 | Find-on-page | Present | Search, next/previous, clear, focus and keyboard dismissal |
| B08 | Content blocking | Missing | Public WKContentRuleList, explicit user toggle, site exception and rollback for broken pages |
| B09 | Save page/share | Missing complete path | User-initiated share/export; opening saved content does not escape permitted file scope |
| B10 | Site-data management | Missing UI | Exact-origin selection and explicit confirmation; never clear every login as a repair default |
| B11 | Video/fullscreen/PiP | Partial web playback | Real YouTube playback, seek, audio routing and fullscreen; service/DRM limits documented |
| B12 | Camera/microphone meetings | Missing verified flow | Per-origin permissions and native prompts; device test for each claimed service |

### Phone handoff and authentication

The reference documents phone-layout handoff for native touch and iframe restrictions, then returning to the external window. It claims page state is retained. Kamihi's separate-WebView implementation cannot yet guarantee that. Source: phone-layout guide above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| H01 | Phone-native touch takeover | Partial separate WebView | Move/reparent the same retained WebView where supported; never attach to two parents simultaneously |
| H02 | Return with state | Partial URL/cookie continuity | Unsaved form text, scroll, navigation stack and tab identity survive both directions |
| H03 | AutoFill, passkeys, OAuth | Physical verification pending | Real provider flows, cancel/error, popup target, redirect and return; never log credentials |
| H04 | File/photo picker and permission prompts | Partial | Present on the phone; correct requesting tab receives selection; cancellation restores focus |
| H05 | Password import | Deliberate alternative | Use native password managers; do not implement raw credential ingestion for parity |

### Files and documents

The reference's Files guide describes persistent folder locations, external drives, file operations, list/grid views, archive extraction, search and unavailable-drive recovery. Source: Files guide above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| F01 | Owned document library | Present copy import | Offline/relaunch, duplicate names, large files and failure UI; originals unchanged |
| F02 | Mounted local/iCloud/USB folders | Missing | Explicit user-selected folders; scoped bookmarks; coordinated reads/writes; stale permission and unplug recovery |
| F03 | Create/rename/move/copy/export | Missing | Collision handling, error reporting, progress/cancel, user-authorized destination only |
| F04 | Trash and restore | Missing | Recover owned deletions; confirmation for permanent deletion; mounted-provider semantics clear |
| F05 | ZIP/unzip | Missing | Reject traversal/symlink escape, size/entry-count bombs and overwrites; cancellation removes temporary files |
| F06 | List/grid/sort/search | Partial flat list | Stable selection, accessible names, large directory limits and scoped search |
| F07 | PDF viewing | Present PDFKit | Native control routing, zoom, scrolling, large/password-protected/corrupt PDFs |
| F08 | PDF annotation/signature/presentation | Missing | Save an explicit copy; undo; annotation reload; fullscreen and page navigation |
| F09 | Office/iWork preview | Present Quick Look path | Actual supported files; unsupported/corrupt state; do not promise native Office editing |
| F10 | Cross-window drag/drop | Missing | Supported payloads only, copy/move semantics, native/phone fallback |

### Photos, media and utility apps

The reference describes a photo library/albums UI and slideshows with timing, transitions, motion, fit/fill, shuffle and repeat. It also advertises image/video/audio viewers and built-in Notes and Calculator. Sources: photos guide and product overview above.

| ID | Target capability | Kamihi audit / work required | Completion test |
|---|---|---|---|
| A01 | Photos library and albums | Missing active implementation | PhotoKit limited/full/denied access; limited selection remains useful; iCloud loading/error |
| A02 | Slideshow | Missing | Timer cancellation, next/previous, repeat/shuffle, fit/fill, Reduce Motion, background/unplug handling |
| A03 | Native video/audio players | Missing complete path | AVKit/AVFoundation, play/pause/seek, audio interruption, route changes, no hidden autoplay |
| A04 | Notes | Partial; phone editor exists | Multi-note editing, autosave, undo, external keyboard, relaunch and export |
| A05 | Calculator | Phone utility; external route missing | Real buttons and keyboard; large values, invalid expressions and division by zero never crash |
| A06 | Clipboard | Phone utility; external route missing | User-initiated paste, private/temporary history and clearing; no silent credential capture |
| A07 | Universal search | Partial app/command search | Apps, tabs, files and notes; scoped local index; correct open result and keyboard selection |
| A08 | App catalog integrity | Missing centralized routing | Every visible launcher tile resolves to a real surface; do not show placeholders as shipped apps |

## Engineering execution order

1. **Input and app routing first.** Introduce a stable `DesktopAppDescriptor` registry shared by launcher, dock, window factory, persistence and phone toolbar. Route native commands to the same app state that renders on the external display. Keep UIKit document pickers, share sheets and native authentication on the phone. Add command-path tests and device execution evidence. Ensure Calculator, PDF and Diagnostics do not open title-only stubs.
2. **Finish the display contract.** Put content scale into one coordinate transform shared by window layout, hit testing, snapping, native controls and WebKit. Use only modes actually returned by UIKit. Test orientation and reconnect. Do not infer actual Hz/HDR from a display model or maximum refresh property.
3. **Preserve handoff identity.** Retain browser controllers per window/tab. Model external/phone ownership explicitly, with teardown on dismissal and recovery on scene loss. Use native AutoFill and passkeys. Do not clone session cookies or credentials into application storage.
4. **Complete the daily browser.** Downloads and installed-site windows first, then zoom, reader, bookmarks, site settings and media. Bound retained WebViews and keep user-visible recovery for terminated web processes.
5. **Complete native documents/media.** One sandbox storage service; asynchronous coordinated file operations; explicit permissions; common preview routing; Photos/AVKit/annotation only after basic native command delivery works.
6. **Polish and measure.** Fullscreen, universal search, discoverable shortcuts, large text/pointer presets, reduced transparency, low power and thermal behavior. Update the main roadmap from executed evidence, not source presence alone.

Each implementation batch must compile iOS, retain macOS regression coverage, pass first-attempt Integration Smoke, exercise changed behavior, and record the exact SHA. A failed identical-SHA rerun is not first-attempt evidence. Do not change production data, export passwords, or add mandatory cloud services for this local desktop.

## Device acceptance script

Use the user's actual iPhone and RayNeo Air 4 Pro. Record iPhone/iOS version, cable/hub, actual reported modes, native/logical bounds, scale and maximum refresh capability. Record actual refresh only with an appropriate measurement source.

1. Fresh install: finish setup without a display. Relaunch; verify completed setup does not repeat.
2. Interrupt on every setup step. Relaunch and resume; review later; confirm no workspace/document settings were reset.
3. Connect before launch, during setup, after setup, while locked and after unlocking. Reconnect five times. Check one external session, correct active windows and no unrequested layout replacement.
4. Open fit guide. Verify four edges and text; change margins. Disconnect/reconnect and close/background setup; ensure no stranded overlay or fake metrics.
5. Exercise slow/fast movement, clicks, right-click, drag, resize, snap, scroll and cancel. Repeat with Bluetooth devices and phone controls.
6. Open every launcher tile. Use real controls on each window through the intended input path; a screenshot alone is insufficient.
7. Browser: tabs, history, bookmarks, downloads, installed sites, reload and session recovery. Test ordinary network loss and WebKit termination.
8. Sign into ChatGPT and YouTube using the phone. Test AutoFill, passkeys where supported, OAuth popup, cancel and CAPTCHA. Confirm unsaved state behavior on return. Never capture credentials in logs or screenshots.
9. Import a PDF and Office document from a provider. Exercise selection, scrolling, zoom, unsupported file and cancel. Verify originals remain unchanged. Test drive removal during reads before enabling write-through mounts.
10. Play video and a slideshow. Validate audio routing, interruptions, fit/fill, pause, fullscreen exit and supported DRM behavior.
11. VoiceOver, largest Dynamic Type, Reduce Motion, Reduce Transparency and light/dark. Check all essential controls remain reachable in portrait and landscape.
12. Run a 60–90 minute session, including power disconnection, Low Power Mode and background/foreground. Measure battery, memory and thermals; no manufactured performance claims.

## Release gate

This change is an onboarding and specification milestone. It does **not** mark the complete parity project done. Release as a full external desktop only after P0 native interaction, catalog routing and same-page handoff are resolved and the relevant rows above pass device acceptance. Keep limitations visible until then.
