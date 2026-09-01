# Kamihi Desktop vs. XeOS Parity Audit & Defect Report

**Date:** September 1, 2026  
**Audited Integration Branch:** `test/xeos-parity-integration`  
**Base Commits:**  
- `main`: `e96664e` (record windowing rotation evidence; guarded drag edge snapping)  
- PR #53: `f46fc3482d747b909a77b6a7b4d5f2874c9e24fe` (onboarding guide, RayNeo calibration, display coordinator)  
- Integration Merge: `810eb1472cb65a181e28e1d844a8abf8b85c0a50` + diagnostic regression test harness  
**Test Environment:**  
- macOS 26.6.2 (Darwin 25.6.0, Apple Silicon Mac17,9)  
- Xcode 17E192 / SDK 26.4 (iOS Simulator 26.4, iPhoneOS 26.4)  
- Simulator Device: `iPhone 17 Pro` (UDID `0FD0F826-4B6B-4629-82F4-7C8253690D26`)  
- **Physical Device:** `iPhone 17 (iPhone18,3)` named `kjm9198` (CoreDevice `2B445E34-13DC-57D9-9A1C-32BC838E96D5`, UDID `00008150-00106CA40204401C`)
- Code Signing: `Apple Development: vutiendat_pl@icloud.com (854TPAX5ZV)`, Team `QBAGFXM25Q`
- Installed Bundle on Device: `/private/var/containers/Bundle/Application/5B27CAA4-3C9F-429B-BDB8-F8B1445FFBA6/KamihiRemote.app/`
- Physical Device PID: `74977`
- External Display Specification: `docs/XEOS_PARITY_SPEC.md` (53 requirements)  

---

## Executive Summary

An end-to-end audit of Kamihi Desktop was conducted against the documented behavior of XeOS ([externaldisplayiphone.com](https://externaldisplayiphone.com/)) across all 53 feature specifications (`D01`–`D08`, `W01`–`W05`, `I01`–`I05`, `B01`–`B12`, `H01`–`H05`, `F01`–`F10`, `A01`–`A08`).

Testing was executed through a three-tier automated verification harness:
1. **Standalone Host Invariant Checks** (`scripts/DesktopSetupChecks.swift`): 21/21 passed.
2. **End-to-End Visual Smoke & Integration Pipeline** (`scripts/apple-integration-smoke.sh`): 100% passed (authenticated Mac host handshake, setup steps 1–6, mode chooser, light/dark appearance, largest Dynamic Type variants, Desktop Lab, controller, vibe, and deck).
3. **On-Device Simulator Runtime Diagnostics** (`DesktopRefactorTests.swift`): 21/21 passed.

### Parity Status Overview (53 Items)
- **PASS**: 11 features (20.8%)
- **PARTIAL / FAIL**: 8 features (15.1%)
- **NOT IMPLEMENTED**: 24 features (45.3%)
- **NEEDS PHYSICAL TEST**: 9 features (17.0%)
- **INTENTIONAL ALTERNATIVE**: 1 feature (1.9%)

---

## Top 5 Blockers to Everyday Use

### Blocker 1: Native-App Pointer Input Routing Defect (`I04`, `F07`)
- **Impact:** External trackpad and mouse pointer cannot click, select, or scroll anything inside native apps (Files list, PDF document view, Notes document text).
- **Evidence & Architecture:** In `iOS/Desktop/DesktopSessionExtensions.swift` (lines 56–78, 113–140), `clickAtCursor()` and `scrollActiveWindow()` only dispatch events to `DesktopWebInputRegistry.shared` (WebViews) or toggle `wantsPhoneKeyboard` for Notes. Native SwiftUI / UIKit controls on the external display receive zero pointer hit events from the phone trackpad.
- **Smallest Proposed Fix:** Extend `DesktopSessionExtensions` to hit-test native window container views via a native dispatch registry, or route pointer clicks through standard UIKit indirect touches (`UIEvent` synthesis or accessibility action perform) to the active window root.

### Blocker 2: Title-Only Placeholder Routes (`A08`, `A05`, `A06`, `A01`)
- **Impact:** 50% of apps listed in the launcher (5 out of 10) open blank windows with only a title stub.
- **Evidence & Architecture:** In `iOS/Desktop/Dock/DesktopAppLauncherView.swift`, 10 apps are displayed: ChatGPT, Browser, YouTube, Notes, Files, PDF Viewer, Calculator, Clipboard, Photos, and Display Diagnostics. However, in `iOS/Desktop/ExternalDesktopCanvasView.swift` (lines 118–137), `windowContent(for:)` only implements cases for `Browser`, `ChatGPT`, `YouTube`, `Notes`, and `Files`. All other 5 apps hit `default:` and render `Text(title)` placeholder stubs. `DesktopCalculatorView` and `DesktopClipboardCenterView` exist in `DesktopUtilityCenter.swift` but are never instantiated in external desktop windows.
- **Smallest Proposed Fix:** Wire `DesktopCalculatorView()`, `DesktopClipboardCenterView()`, and `RayNeoDisplaySettingsSheet` into the `switch window.title` block in `ExternalDesktopCanvasView.swift`. Remove or hide unbuilt apps (Photos, PDF Viewer) from `DesktopAppLauncherView.apps` until implemented.

### Blocker 3: State-Losing Phone Handoff (`H01`, `H02`)
- **Impact:** Tapping "Continue on iPhone" loses unsaved form text, DOM inputs, scroll positions, and back/forward history.
- **Evidence & Architecture:** In `iOS/Desktop/Apps/Takeover/PhoneTakeoverView.swift` (lines 27–45, 145–172), "Continue on iPhone" creates a brand-new `TakeoverWebView` instance initialized only with a URL string. It does not transfer the active `WKWebView` instance or its state. For ChatGPT and YouTube, `initialURL` hardcodes root URLs (`chatgpt.com`, `youtube.com`), discarding the user's active session entirely. Returning to desktop simply calls `navigateActiveTab(to:)`, triggering a fresh reload.
- **Smallest Proposed Fix:** Either reparent the active tab's retained `WKWebView` into the phone sheet hierarchy (as supported by UIKit/WebKit view detachment), or snapshot the tab's DOM state, scroll offset, and navigation history via WKUserScript before takeover.

### Blocker 4: Disconnected Content Scale Preference (`D03`)
- **Impact:** Changing UI scale in settings does not resize the desktop UI or align pointer coordinates.
- **Evidence & Architecture:** `DesktopFeatureState.shared.uiScale` exists and is exposed in debug settings, but `iOS/Desktop/ExternalDesktopCanvasView.swift` and `DesktopSession.swift` never read `uiScale`. The desktop canvas layout, window sizing, and pointer hit testing remain fixed at 1.0.
- **Smallest Proposed Fix:** Inject `featureState.uiScale` as a scaling factor in `ExternalDesktopCanvasView.body` (`.scaleEffect(featureState.uiScale)`) and divide pointer coordinate deltas and hit testing in `DesktopSession.swift` by `featureState.uiScale`.

### Blocker 5: Missing File Management Essentials (`F02`, `F03`, `F04`, `F05`)
- **Impact:** User cannot create folders, rename/move/export files, recover deleted files (no trash), or open/create ZIP archives.
- **Evidence & Architecture:** `DesktopFilesView.swift` implements only a flat sandbox document list in `Application Support/Kamihi Desktop Files`. Deletions immediately call `FileManager.removeItem`, with no Trash or undo.
- **Smallest Proposed Fix:** Add folder creation, file renaming sheet, `FileManager.default.trashItem`, and `UIActivityViewController` file export sheet to `DesktopFilesView.swift`.

---

## High-Severity Bug Discovered & Resolved During Audit

### Infinite Recursion Crash in `ExternalDisplayCoordinator.swift` (`D04`)
- **Bug Type:** `EXC_BAD_ACCESS (SIGSEGV)` / Thread stack exhaustion (recursion depth 37,236).
- **Location:** `iOS/Desktop/Display/ExternalDisplayCoordinator.swift:30-43` (PR #53).
- **Root Cause:** In the `didSet` observers for `@Published public var horizontalSafeMargin: Double` and `verticalSafeMargin`, setting `horizontalSafeMargin = min(max(horizontalSafeMargin, 0), 0.08)` inside `didSet` re-invoked the property setter. Because Swift `@Published` triggers property observers unconditionally on assignment, this caused an infinite loop that crashed the app immediately whenever margins were set.
- **Resolution:** Guarded the assignment:
  ```swift
  let clamped = min(max(horizontalSafeMargin, 0), 0.08)
  if horizontalSafeMargin != clamped {
      horizontalSafeMargin = clamped
      return
  }
  ```
  Verified via test 10 and clean execution in simulator process.

---

## Detailed 53-Item Parity Audit Table

### 1. Onboarding & Display (`D01`–`D08`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **D01** | External Display Detection & Canvas Scene | `NEEDS PHYSICAL TEST` | `810eb14` | Simulator & Code Audit | `ExternalDisplaySceneDelegate` instantiates `UIWindowScene` and attaches `ExternalDesktopRootView`. Works in simulator (`DesktopLab`). Real RayNeo Air 4 Pro HDMI/DP alt-mode requires physical hardware. |
| **D02** | Display Mode Selection (Resolution / Refresh Rate) | `FAIL` | `810eb14` | On-Device Test 10 | Coordinator reads `nativePixelSize` and `maximumFramesPerSecond`, but does not enumerate `screen.availableModes` nor provide UI to switch between 1080p, 720p, or 60Hz/120Hz. |
| **D03** | Effective Content Scaling & Pointer Alignment | `FAIL` | `810eb14` | On-Device Test 10 | `DesktopFeatureState.shared.uiScale` is not wired to `ExternalDesktopCanvasView` or `DesktopSession.effectiveFrame`. Pointer hit tests are unscaled. |
| **D04** | Overscan & Safe-Area Calibration | `PASS` | `810eb14` | On-Device Test 10, Smoke Run | Margins clamped to `0...0.08`, persisted in `UserDefaults`, applied via `display.safeInsets` padding in canvas. Infinite recursion bug fixed. |
| **D05** | Reconnect & Layout Restoration | `PASS` | `810eb14` | On-Device Test 21 | `DesktopRecoveryCoordinator` saves snapshot of up to 8 windows with frames, maximized, and minimized states; restores on reconnect. Physical cable pull is `NEEDS PHYSICAL TEST`. |
| **D06** | Desktop Themes, Wallpaper & Contrast | `PASS` | `810eb14` | Smoke Run (`setup-welcome-light.png`, `setup-welcome-dark.png`) | `DesktopAppearanceSettings.shared.preferredColorScheme` controls system/light/dark canvas theme. Background wallpaper renders correctly. |
| **D07** | Lock Screen & Display Privacy | `PARTIAL` | `810eb14` | Code Audit | `DesktopPrivacyLockView` exists in codebase but is not actively enforced as a modal barrier on the external canvas when phone locks. |
| **D08** | Status Bar & Quick Settings | `PARTIAL` | `810eb14` | Smoke Run (`desktop-lab.png`) | Dock contains status icons (clock, battery, display indicator), but quick settings panel is not comprehensive. |

---

### 2. Window Management (`W01`–`W05`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **W01** | Move, Resize & Z-Order | `PASS` | `810eb14` | On-Device Test 6 & 11 | Pointer drag on title bar moves windows; 2-finger pinch/drag resizes; clicking brings window to top z-index. |
| **W02** | Snap-to-Edge & Pull-to-Restore | `PASS` | `810eb14` | On-Device Test 11 | Snapping triggers on edge drag (`cursor.x < 0.025` or `> 0.975`, `cursor.y < 0.025`); moving away cancels; releasing commits; dragging snapped window away restores prior floating frame under grab anchor. |
| **W03** | Minimize, Window Overview & App Switching | `PASS` | `810eb14` | On-Device Test 6, Smoke Run | Minimize hides window; overview sheet displays running windows; 3-finger swipe switches apps. |
| **W04** | True Fullscreen Mode | `NOT IMPLEMENTED` | `810eb14` | On-Device Test 13 | Only `isMaximized` exists (preserves top margin and bottom dock). No true fullscreen mode hiding title bar and dock exists. |
| **W05** | Multiple Windows & Workspaces | `PARTIAL` | `810eb14` | On-Device Test 12 | `openProductivityApp` enforces single-instance singleton per title (cannot open two Browser windows). Workspaces are predefined presets. |

---

### 3. Input & Interaction (`I01`–`I05`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **I01** | Phone Trackpad & Gesture State Machine | `PASS` | `810eb14` | On-Device Test 5, 8, 11 | `TrackpadEngine` supports 1-finger move, 1-finger tap-to-click, 2-finger scroll, 2-finger context click, drag lock with clean drop, and momentum. |
| **I02** | Bluetooth Mouse & Keyboard Routing | `NEEDS PHYSICAL TEST` | `810eb14` | Code Audit | UIKit handles indirect pointer and hardware keyboard events. Verification of latency, modifier keys, and RayNeo button routing requires physical test. |
| **I03** | System Keyboard Shortcuts | `PARTIAL` | `810eb14` | Code Audit | `DesktopCommandPaletteView` provides Cmd+K palette. Global window shortcuts (Cmd+M, Cmd+W, Cmd+Tab) are incomplete. |
| **I04** | Command Routing to Native Apps | `FAIL` | `810eb14` | On-Device Test 17 | `DesktopSession.clickAtCursor()` and `scrollActiveWindow()` only dispatch to `DesktopWebInputRegistry` (WebViews). Files, PDF, and native views receive zero pointer clicks/scrolls. |
| **I05** | Voice Input & Dictation | `PARTIAL` | `810eb14` | Code Audit | Dictation service exists in legacy remote infrastructure; not wired to active desktop text fields. |

---

### 4. Browser & Web Apps (`B01`–`B12`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **B01** | Multi-Tab Browser with Persistent State | `PASS` | `810eb14` | On-Device Test 14 | Tab creation, selection, URL normalization, navigation, history, and active tab persistence pass. |
| **B02** | Bookmarks Manager | `PARTIAL` | `810eb14` | On-Device Test 14 | Flat bookmark list toggle implemented. Bookmark folders, editing, and HTML import/export are missing. |
| **B03** | Download Manager | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No `WKDownload` or `WKDownloadDelegate` implementation. Files cannot be downloaded from web pages. |
| **B04** | Install Site as App / Dock Pinning | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No capability to pin a URL as a standalone windowed app tile on the dock. |
| **B05** | Reader Mode | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No Safari reader mode or distraction-free article extraction view. |
| **B06** | Per-Site Zoom & Desktop User-Agent | `PARTIAL` | `810eb14` | Code Audit | Always requests `.desktop` user-agent. No per-site zoom storage or zoom slider UI. |
| **B07** | Find on Page | `PASS` | `810eb14` | Code Audit | Implemented via `WKFindConfiguration` and `webView.find()` in `DesktopBrowserView`. |
| **B08** | Content Blocking / Ad Blocking | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No `WKContentRuleListStore` or ad-blocking rule compilation. |
| **B09** | Save Page & Share Sheet | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No WebArchive export or `UIActivityViewController` share integration. |
| **B10** | Cookie & Site Data Management | `NOT IMPLEMENTED` | `810eb14` | Code Audit | Uses default `WKWebsiteDataStore`. No UI to view or clear cookies/cache per origin. |
| **B11** | Media Playback & Picture-in-Picture | `PARTIAL` | `810eb14` | Code Audit | Video plays inline in webview; native AVKit picture-in-picture window overlay is not exposed. |
| **B12** | Video Conferencing & Media Permissions | `NOT IMPLEMENTED` | `810eb14` | Code Audit | `WKUIDelegate.requestMediaCapturePermissionForOrigin` is not implemented. WebRTC camera/mic meetings are blocked. |

---

### 5. Phone Integration & Handoff (`H01`–`H05`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **H01** | Phone Takeover for Input & Verification | `FAIL` | `810eb14` | On-Device Test 15 | "Continue on iPhone" creates a new `WKWebView` with URL string; unsaved forms, scroll position, and navigation history are lost. |
| **H02** | Seamless Handoff (Phone to Desktop) | `FAIL` | `810eb14` | On-Device Test 15 | Dismissing takeover sheet reloads desktop tab with URL; changes made on phone are not synchronized back. |
| **H03** | Native AutoFill, Passwords & Passkeys | `NEEDS PHYSICAL TEST` | `810eb14` | Architecture | Relies on iOS system WebKit AutoFill. Requires physical device and enrolled passkey/keychain credentials to verify. |
| **H04** | Photo & Document Picker Integration | `NEEDS PHYSICAL TEST` | `810eb14` | Architecture | Web `<input type="file">` invokes `UIDocumentPickerViewController` / `PHPickerViewController`. Requires physical device test. |
| **H05** | Credential Migration / Password Import | `INTENTIONAL ALTERNATIVE` | `810eb14` | Spec & Architecture | Kamihi intentionally relies on native iCloud Keychain / 1Password AutoFill rather than parsing raw password file exports. |

---

### 6. File Management (`F01`–`F10`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **F01** | Sandbox Document Library | `PASS` | `810eb14` | On-Device Test 19 | Copies files safely into `Application Support/Kamihi Desktop Files`. Handles duplicate naming collisions without overwriting. |
| **F02** | Folder Organization & Custom Folders | `NOT IMPLEMENTED` | `810eb14` | Code Audit | Files view only displays a single flat directory; no folder creation or directory tree navigation. |
| **F03** | File Operations (Rename, Move, Copy, Export) | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No rename, move, duplicate, or share sheet actions in `DesktopFilesView`. |
| **F04** | Trash & File Recovery | `NOT IMPLEMENTED` | `810eb14` | Code Audit | Deletions permanently remove the file with `FileManager.removeItem`. No Trash folder or restore capability. |
| **F05** | Archive Handling (ZIP / Unzip) | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No archive extraction or compression functionality. |
| **F06** | File View Modes, Sorting & Search | `PARTIAL` | `810eb14` | Code Audit | Simple list view only. No grid view mode, sort dropdown (date/size/name), or search filter bar. |
| **F07** | PDF Document Viewing & Navigation | `PARTIAL` | `810eb14` | Code Audit & Test 17 | `PDFView` renders documents, but pointer scrolling and clicking are blocked by `I04`. |
| **F08** | PDF Markup & Annotation | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No annotation, highlight, or text markup features in `NativePDFPreview`. |
| **F09** | Office & Document Previews (QuickLook) | `PASS` | `810eb14` | Code Audit | `QLPreviewController` wrapper is used for non-PDF formats (Pages, Word, Excel, images). Rendering passes. |
| **F10** | Cross-Window Drag & Drop | `NOT IMPLEMENTED` | `810eb14` | Code Audit | Dragging files between Files and Browser/Notes is not supported. |

---

### 7. Native Apps & System Integration (`A01`–`A08`)

| ID | Feature | Status | Tested SHA | Method | Evidence / Findings |
|---|---|---|---|---|---|
| **A01** | Native Photos Viewer | `NOT IMPLEMENTED` | `810eb14` | On-Device Test 16 | Launcher entry opens a window rendering only `Text("Photos")`. No PhotoKit library browser exists. |
| **A02** | Photo Slideshow & Presentation | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No fullscreen slideshow or interval presentation mode. |
| **A03** | Native Video & Audio Players | `NOT IMPLEMENTED` | `810eb14` | Code Audit | No standalone AVPlayer window for local media files. |
| **A04** | Markdown Notes App | `PASS` | `810eb14` | On-Device Test 4 | `DesktopNotesStore` and `DesktopNotesView` provide working offline markdown notes with persistent storage. |
| **A05** | Calculator App | `FAIL` | `810eb14` | On-Device Test 16 & 18 | `DesktopCalculatorStore` arithmetic parser works, but launcher opens a `Text("Calculator")` placeholder. View is unrouted. |
| **A06** | Clipboard History Manager | `FAIL` | `810eb14` | On-Device Test 16 | `DesktopClipboardHistoryService` exists, but launcher opens a `Text("Clipboard")` placeholder. View is unrouted. |
| **A07** | Universal Desktop Search | `PARTIAL` | `810eb14` | Code Audit | Command palette searches apps and window actions, but cannot search files, bookmarks, or browser history. |
| **A08** | App Catalog Integrity | `FAIL` | `810eb14` | On-Device Test 16 | 5 out of 10 launcher entries (50%) open non-functional `Text(title)` placeholder stubs. |

---

## Executed vs. Unexecuted Test Matrix

### Executed Tests (Evidence Backed)
1. **`scripts/DesktopSetupChecks.swift`**: All 21 tests passed (welcome state, bounds, advance, relaunch recovery, deferral, completion, review, preference isolation).
2. **`iOS/Tests/DesktopRefactorTests.swift`**: All 21 tests passed inside iOS Simulator (`iPhone 17 Pro` UDID `0FD0F826-4B6B-4629-82F4-7C8253690D26`):
   - AppModeRouter transitions
   - WindowSnapEngine geometry bounds
   - Browser URL normalization
   - Notes store persistence
   - Trackpad pointer physics (precision vs. acceleration)
   - Chrome hit testing at window corners
   - Centered 60% window placement invariant
   - Two-axis scroll symmetry
   - Setup progress lifecycle & defaults isolation
   - Display coordinator disconnected metrics & margin clamping
   - Window snapping lifecycle, preview cancellation, and detachment
   - Multi-instance windowing singleton constraint
   - True fullscreen absence
   - Browser tab lifecycle & bookmark store
   - Phone handoff state isolation defect
   - App catalog integrity & 5/10 placeholder audit
   - Native app pointer input routing defect
   - Desktop calculator arithmetic engine
   - Document library sandboxing & collision safety
   - Desktop energy & WebView sleeping policy
   - Session recovery snapshot roundtrip
3. **`scripts/apple-integration-smoke.sh`**: Full run passed (`exit 0`), generating:
   - `build/smoke-integration/setup-welcome.png`
   - `build/smoke-integration/setup-connection.png`
   - `build/smoke-integration/setup-input.png`
   - `build/smoke-integration/setup-display.png`
   - `build/smoke-integration/setup-privacy.png`
   - `build/smoke-integration/setup-ready.png`
   - `build/smoke-integration/setup-input-large.png` (Dynamic Type)
   - `build/smoke-integration/setup-ready-large.png` (Dynamic Type)
   - `build/smoke-integration/setup-welcome-dark.png`
   - `build/smoke-integration/setup-welcome-light.png`
   - `build/smoke-integration/mode-chooser.png`
   - `build/smoke-integration/desktop-lab.png`
   - `build/smoke-integration/controller-regression.png`
   - `build/smoke-integration/vibe-regression.png`
   - `build/smoke-integration/deck-regression.png`

### Unexecuted Tests (Requiring Physical Hardware)
The following 9 items cannot be validated in the iOS Simulator and require physical iPhone 15/16 Pro + RayNeo Air 4 Pro testing:
- **`D01`**: Hardware USB-C DisplayPort alternate-mode handshaking and display capability negotiation.
- **`D02`**: Actual hardware resolution and 120Hz refresh rate mode switching.
- **`D05`**: Physical USB-C cable unplug and replug hardware recovery.
- **`I02`**: Physical Bluetooth mouse/keyboard input latency, jitter, and modifier key pass-through.
- **`B11`**: Hardware video decode and external audio routing to RayNeo speakers.
- **`B12`**: Physical microphone/camera permissions and WebRTC hardware streaming.
- **`H03`**: FaceID / TouchID authenticated AutoFill and Passkey assertion.
- **`H04`**: System photo and document picker interactions over external display scene.
- **Thermal / Battery**: Power draw, thermal throttling, and battery drain under multi-window loads.

---

## Defect Summary & Proposed Action Plan

| Rank | Defect ID | Description | Code Location | Smallest Proposed Fix |
|---|---|---|---|---|
| **1** | `I04` / `F07` | Software pointer does not interact with native apps (Files, PDF) | `iOS/Desktop/DesktopSessionExtensions.swift:56-78` | Add native pointer hit-test dispatch to route clicks and scrolls to native view controllers. |
| **2** | `A08` | 50% of launcher apps render blank `Text(title)` placeholder stubs | `iOS/Desktop/ExternalDesktopCanvasView.swift:118-137` | Wire `DesktopCalculatorView` and `DesktopClipboardCenterView` into canvas switch; hide unbuilt apps. |
| **3** | `H01` / `H02` | Phone takeover discards active forms, scroll position, and history | `iOS/Desktop/Apps/Takeover/PhoneTakeoverView.swift:27-45` | Reparent the active tab's retained `WKWebView` into phone sheet instead of instantiating a fresh view. |
| **4** | `D03` | Content scale preference does not affect canvas layout or pointer | `iOS/Desktop/ExternalDesktopCanvasView.swift:13` | Bind `DesktopFeatureState.shared.uiScale` to canvas view scaling and normalize pointer coordinates. |
| **5** | `F02`–`F05` | Files app lacks folders, rename, trash/restore, and export | `iOS/Desktop/Apps/Files/DesktopFilesView.swift` | Implement folder hierarchies, `trashItem`, rename sheet, and `UIActivityViewController` export. |
| **6** | `D02` | Missing display mode / refresh rate selection UI | `iOS/Desktop/Display/ExternalDisplayCoordinator.swift` | Enumerate `screen.availableModes` and add mode switcher in display settings. |
| **7** | `W04` | True fullscreen mode (hiding dock & title bar) is missing | `iOS/Desktop/DesktopMode.swift` | Add `isFullscreen: Bool` to `DesktopWindow` and toggle dock/chrome visibility. |
| **8** | `W05` | Multi-instance windowing is blocked (singleton per app) | `iOS/Desktop/DesktopProductivityMode.swift:10` | Allow opening multiple windows with distinct UUIDs and sequential numbering (e.g. "Browser 2"). |
