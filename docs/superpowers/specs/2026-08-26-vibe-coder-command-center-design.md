# Kamihi Remote: Vibe Coder Mission Control & Developer Remote Specification

**Date:** 2026-08-26  
**Status:** Approved  
**Author:** Pair Programming Agent & Michael (kjm9198)

---

## 1. Overview & Vision

Kamihi Remote evolves from a low-latency Mac trackpad into a **phone-first command center for coding and controlling your Mac**. When away from your desk or lounging while an AI coding agent runs, Kamihi Remote gives you total supervision, code editing, terminal execution, dev server monitoring, and gesture precision directly from your iPhone.

---

## 2. Information Architecture (5 Primary Tabs)

The primary bottom navigation bar provides 5 dedicated workspaces:

```
[ ⚡ Vibe ]   [ 🖱 Trackpad ]   [ 🎛 Deck ]   [ ⌨️ CodeKey ]   [ 🎮 Gamepad ]
```

### 2.1 Tab 1: `⚡ Vibe` (Mission Control Hub)
- **Status Header:** Displays connected Mac name (e.g. `MP9198`), connection state (green dot), active frontmost app pill (e.g. `Active: Visual Studio Code`), and Mac battery/system pulse.
- **AI / Voice Command Bar:** One-tap trigger to dictate or type natural language instructions to Mac agents (`"Fix failing tests"`, `"Start frontend dev server"`, `"Commit changes with message"`).
- **Quick Action Grid:**
  - `Toggle Dev Server` (Starts/stops default project dev server)
  - `Git Status` (Runs git status on active repo)
  - `Quick Screenshot` (Captures region/window on Mac)
  - `Spaces Jump` (Quick jump to Desktop 1, 2, 3)
- **Activity & Project Cards:** High-level project launcher overview showing project state and localhost port status.

### 2.2 Tab 2: `🖱 Trackpad` (Live Trackpad Pro)
- **Core Input Engine:**
  - 1 finger: Cursor movement (smooth UDP packets) + left tap
  - 2 fingers: Continuous vertical/horizontal fluid pixel scrolling + 2-finger tap for right-click
  - 3 fingers swipe left: Previous Desktop (`⌃←`)
  - 3 fingers swipe right: Next Desktop (`⌃→`)
  - 3 fingers swipe up: Mission Control
  - 3 fingers swipe down: App Exposé
  - 2-finger pinch: Zoom In / Zoom Out (`⌘+` / `⌘-`)
- **Particle & Visual Feedback:** Glowing touch dots trailing active touch points, fluid ripple rings on tap, and directional swipe trails.
- **Radial Action Wheel:** Long-press gesture reveals a 6-sector quick wheel (`Vibe`, `Deck`, `CodeKey`, `Spaces`, `Apps`, `Terminal`).

### 2.3 Tab 3: `🎛 Deck` (Context-Aware Command Deck 2.0)
- **Adaptive Frontmost App Profiles:**
  - **VS Code / Cursor (`com.microsoft.VSCode`):** `Save (⌘S)`, `Command Palette (⌘⇧P)`, `Terminal (⌃\`)`, `Quick Open (⌘P)`, `Format (⌥⇧F)`, `Run (F5)`, `Git (⌃⇧G)`.
  - **Terminal / Ghostty / iTerm2:** `Ctrl+C (⌃C)`, `Clear (⌘K)`, `History Up (↑)`, `npm run dev`, `git status`, `git diff`, `git push`.
  - **Chrome / Safari / Arc:** `New Tab (⌘T)`, `Close Tab (⌘W)`, `Next Tab (⌘⌥→)`, `Prev Tab (⌘⌥←)`, `DevTools (⌥⌘I)`, `Hard Reload (⌘⇧R)`.
  - **Xcode (`com.apple.dt.Xcode`):** `Build (⌘B)`, `Run (⌘R)`, `Stop (⌘.)`, `Clean (⌘⇧K)`, `Canvas (⌥⌘P)`.
- **Page Categories:** `[Auto-Detect]`, `[Coding]`, `[Terminal]`, `[Browser]`, `[System]`.
- **Integrated Mini Trackpad:** Lower strip preserves cursor navigation while tapping Deck buttons.

### 2.4 Tab 4: `⌨️ CodeKey` (Dedicated Coding Keyboard)
- **Live macOS Focus Mirror:** Continuously reads the focused text element on macOS via the Accessibility API (`AXUIElementCopyAttributeValue`), allowing phone-side viewing, editing, and replacement.
- **System Modifier Toolbar:** `Esc`, `⌘`, `⌥`, `⌃`, `⇧`, `Tab`, `Space`, `⌫`, `Return`, `↑`, `↓`, `←`, `→`.
- **Developer Syntax Palette:**
  - Brackets & Arrows: `{ }`, `( )`, `[ ]`, `< >`, `=>`, `->`, `&&`, `||`, `!`, `?`
  - Code Punctuation: `;`, `:`, `"`, `'`, `/`, `\`, `=`, `+`, `-`, `_`, `$`, `.`, `%`
- **One-Tap Code Snippets:** `console.log()`, `print()`, `git status`, `npm run dev`, `return `, `func `.

### 2.5 Tab 5: `🎮 Gamepad` (Virtual Controller & Presentation)
- Virtual controller with customizable dual-stick mouse/WASD mapping, media controls, and presentation laser pointer overlay.

---

## 3. Protocol & Telemetry Architecture

### 3.1 New Wire Commands (`Shared/RemoteCommand.swift`)
1. `ACTIVE_APP <bundleID> <quoted(displayName)>`:
   - Sent by host to iPhone on application switch.
2. `REQUEST_ACTIVE_APP`:
   - Sent by iPhone on connect to retrieve the initial frontmost application.
3. `RUN_COMMAND <quoted(commandText)>`:
   - Runs shell/script actions on Mac host with execution ACK.

### 3.2 macOS Host Daemon Telemetry (`macOS/HostSession.swift`)
- Listens to `NSWorkspace.didActivateApplicationNotification`.
- Queries `NSWorkspace.shared.frontmostApplication`.
- Broadcasts `ACTIVE_APP` payload over reliable TCP to active client.

---

## 4. Quality & Verification Gates

1. **Protocol Unit Tests:** Serialization & deserialization round-trip for new commands (`ACTIVE_APP`, `RemoteTab` enum expansion).
2. **Gesture & Modifier Injection Tests:** Verification of Mac keycode and modifier injection via `InputEngine`.
3. **Physical Device Build & Execution:** Build `KamihiRemote` scheme for iPhone 17 (`kjm9198`) via `devicectl` and deploy `KamihiRemoteHost` to `/Applications`.
