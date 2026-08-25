# Vibe Coder Command Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Kamihi Remote into a phone-first developer mission control and vibe coding companion with 5 primary workspaces (Vibe Hub, Trackpad Pro, Context Deck, Coding Keyboard, Gamepad), active app Mac telemetry, and developer tool integration.

**Architecture:** Extend `RemoteCommand` wire protocol with active app telemetry (`ACTIVE_APP`). Implement host-side frontmost app monitoring in `macOS/HostSession.swift`. Build `iOS/VibeHubScreen.swift` and `iOS/CodingKeyboardScreen.swift`, enhance `DeckScreen` with context-aware app profiles, and integrate all 5 tabs into `KamihiPolishedRootView`.

**Tech Stack:** Swift, SwiftUI, AppKit (`NSWorkspace`), CoreGraphics, Network.framework (TCP/UDP), AVFoundation / Speech.

**Spec:** `docs/superpowers/specs/2026-08-26-vibe-coder-command-center-design.md`

## Global Constraints
- Do NOT invert 3-finger left/right gestures (`3-finger left = ⌃← Previous Desktop`, `3-finger right = ⌃→ Next Desktop`).
- Physical device deployment target is Michael's iPhone 17 (`kjm9198`) via `xcrun devicectl`.
- Preserve backward compatibility and TCP ACK guarantees for all Deck, key, and system actions.

---

### Task 1: Protocol & Shared Models

**Files:**
- Modify: `Shared/RemoteCommand.swift`
- Modify: `Shared/AppPreferences.swift`
- Modify: `iOS/GestureEngineTests.swift` (or new test suite)

**Interfaces:**
- Produces:
  - `RemoteCommand.activeApp(bundleID: String, name: String)`
  - `RemoteCommand.requestActiveApp`
  - `RemoteTab`: `.vibe`, `.trackpad`, `.deck`, `.codeKey`, `.controller`

- [ ] **Step 1: Write unit tests for new RemoteCommands and RemoteTab**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement RemoteCommand wire serialization and RemoteTab cases**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit changes**

---

### Task 2: macOS Host Active App Telemetry

**Files:**
- Modify: `macOS/HostSession.swift`
- Modify: `macOS/InputEngine.swift`

**Interfaces:**
- Produces:
  - Host broadcasts `ACTIVE_APP <bundleID> <name>` on application switch and upon receiving `REQUEST_ACTIVE_APP`.

- [ ] **Step 1: Add frontmost application notification listener in `HostSession.swift`**
- [ ] **Step 2: Handle `REQUEST_ACTIVE_APP` in `HostSession.handleReliable`**
- [ ] **Step 3: Test host build & active app broadcast parsing**
- [ ] **Step 4: Commit changes**

---

### Task 3: Dedicated Coding Keyboard Screen

**Files:**
- Create: `iOS/CodingKeyboardScreen.swift`
- Modify: `iOS/RemoteSession.swift`

**Interfaces:**
- Produces:
  - `CodingKeyboardScreen`: Live focus mirror, system modifier row (`Esc`, `⌘`, `⌥`, `⌃`, `⇧`, `Tab`, `↑`, `↓`, `←`, `→`), developer syntax palette (`{}`, `()`, `[]`, `<>`, `=>`, `&&`, `||`, `;`, `:`), and code snippet bar.

- [ ] **Step 1: Implement `CodingKeyboardScreen.swift` with modifier state and symbol matrix**
- [ ] **Step 2: Connect live focused text synchronization to `RemoteSession`**
- [ ] **Step 3: Test keyboard input flow and modifier toggles**
- [ ] **Step 4: Commit changes**

---

### Task 4: Context-Aware Deck 2.0

**Files:**
- Modify: `iOS/FeatureScreens.swift`
- Create: `iOS/ContextDeckProfiles.swift`

**Interfaces:**
- Produces:
  - `ContextDeckProfiles`: App profiles for VS Code / Cursor, Terminal / Ghostty, Chrome / Safari, Xcode, and System shortcuts with auto-detection.

- [ ] **Step 1: Create `ContextDeckProfiles.swift` with curated developer actions per app**
- [ ] **Step 2: Update `DeckScreen` in `iOS/FeatureScreens.swift` to support auto-detection and page filtering**
- [ ] **Step 3: Test Deck profile switching**
- [ ] **Step 4: Commit changes**

---

### Task 5: Vibe Mode Mission Control Screen

**Files:**
- Create: `iOS/VibeHubScreen.swift`
- Modify: `iOS/RemoteSession.swift`

**Interfaces:**
- Produces:
  - `VibeHubScreen`: Hero header, AI / voice command trigger, quick action grid (Dev server, Git status, Screenshot, Spaces), and active project preview cards.

- [ ] **Step 1: Implement `VibeHubScreen.swift` layout and cards**
- [ ] **Step 2: Wire quick action triggers and AI dictation bar into `RemoteSession`**
- [ ] **Step 3: Test Vibe Hub interaction and command routing**
- [ ] **Step 4: Commit changes**

---

### Task 6: Shell Integration & Tab Navigation

**Files:**
- Modify: `iOS/PolishedV04UI.swift`
- Modify: `iOS/RemoteSession.swift`

**Interfaces:**
- Produces:
  - `KamihiPolishedRootView` with 5 bottom tabs (`⚡ Vibe`, `🖱 Trackpad`, `🎛 Deck`, `⌨️ CodeKey`, `🎮 Gamepad`) across Portrait, Landscape, and iPad layouts.

- [ ] **Step 1: Update tab views and primary navigation bar in `iOS/PolishedV04UI.swift`**
- [ ] **Step 2: Ensure safe area padding and responsiveness across device orientations**
- [ ] **Step 3: Test build of `KamihiRemote` scheme**
- [ ] **Step 4: Commit changes**

---

### Task 7: Physical Device Build, Host Install & Runtime Verification

**Files:**
- System deployment

- [ ] **Step 1: Build macOS host and install to `/Applications/KamihiRemoteHost.app`**
- [ ] **Step 2: Build iOS app for physical iPhone 17 (`kjm9198`) via `xcrun devicectl`**
- [ ] **Step 3: Install and launch on physical device**
- [ ] **Step 4: Verify live execution and record evidence**
- [ ] **Step 5: Git commit & push to `origin main`**
