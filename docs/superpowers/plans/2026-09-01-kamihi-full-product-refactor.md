# Kamihi Full Product Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Kamihi Remote into two clearly separated product experiences inside one installed iOS app: Remote for Mac (MacBook remote control) and Kamihi Desktop (iOS 27 external display / DeX-style native experience).

**Architecture:** A dedicated `AppModeRouter` manages the launch `ModeSelectionView`, switching between `RemoteMacRootView` and `ExternalDesktopRootView` / `DesktopLabView`. Shared services (encryption, packet protocols, haptics, theme tokens) are decoupled from the UI. Kamihi Desktop features a minimalist 3-area phone controller, an advanced trackpad engine, custom cursor styles, modular window management with snapping, native Notes and Files, Phone Takeover for web authentication, and a local Desktop Lab for testing.

**Tech Stack:** Swift, SwiftUI, UIKit, WebKit, CoreGraphics, Network.framework, CryptoKit, Security.framework.

**Spec:** Prompt specification for KAMIHI REMOTE — FULL PRODUCT REFACTOR.

## Global Constraints
- Target platform: iOS 26.0+ / iOS 27.0+ compatibility for iPhone and iPad.
- Swift 6 language standard conformance with strict actor isolation.
- No private Apple APIs.
- Absolute preservation of existing Remote for Mac pairing, security, encryption, and network protocol functionality.
- No dummy/placeholder buttons; every UI element is connected to an active handler.

---

### Task 1: Theme & Semantic Design Tokens (`iOS/Theme/`)

**Files:**
- Create: `iOS/Theme/KamihiTheme.swift`

- [ ] **Step 1: Implement KamihiTheme with semantic spacing, radii, colors, materials, and spring animations**
- [ ] **Step 2: Verify compilation against iOS target**

---

### Task 2: Application Mode & Router Layer (`iOS/App/`)

**Files:**
- Create: `iOS/App/AppMode.swift`
- Create: `iOS/App/AppModeRouter.swift`
- Create: `iOS/App/ModeSelectionView.swift`

- [ ] **Step 1: Implement AppMode with launch argument overrides**
- [ ] **Step 2: Implement AppModeRouter with mode transitions and test hooks**
- [ ] **Step 3: Implement ModeSelectionView with Apple-native cards and typography**
- [ ] **Step 4: Verify mode transitions in unit tests**

---

### Task 3: Remote for Mac Isolation (`iOS/Remote/`)

**Files:**
- Create: `iOS/Remote/RemoteMacRootView.swift`

- [ ] **Step 1: Encapsulate Remote for Mac controls (trackpad, keyboard dock, shortcut deck, Vibe hub, connection chip, settings) in RemoteMacRootView**
- [ ] **Step 2: Ensure zero WebKit or desktop window initialization in Remote mode**

---

### Task 4: Original Kamihi Cursor & Interaction System (`iOS/Desktop/Cursor/`)

**Files:**
- Create: `iOS/Desktop/Cursor/CursorStyle.swift`
- Create: `iOS/Desktop/Cursor/CursorInteractionState.swift`
- Create: `iOS/Desktop/Cursor/DesktopCursorView.swift`

- [ ] **Step 1: Implement CursorStyle enum (Kamihi Dot, Classic Arrow, Precision, Large Accessibility)**
- [ ] **Step 2: Implement CursorInteractionState and spring animated DesktopCursorView**

---

### Task 5: Trackpad Engine & Gesture State Machine (`iOS/Desktop/Controller/`)

**Files:**
- Create: `iOS/Desktop/Controller/TrackpadEngine.swift`
- Create: `iOS/Desktop/Controller/TrackpadSettings.swift`
- Create: `iOS/Desktop/Controller/ContextualControllerToolbar.swift`
- Create: `iOS/Desktop/Controller/DesktopControllerView.swift`

- [ ] **Step 1: Implement TrackpadEngine with velocity acceleration, precision mode, scroll isolation, drag lock, and gesture state machine**
- [ ] **Step 2: Implement TrackpadSettings sheet and ContextualControllerToolbar**
- [ ] **Step 3: Implement 3-area DesktopControllerView (Status/Header, Trackpad, Bottom Toolbar)**

---

### Task 6: Desktop Windowing, Snapping, and Overview (`iOS/Desktop/Windowing/`)

**Files:**
- Create: `iOS/Desktop/Windowing/WindowSnapEngine.swift`
- Create: `iOS/Desktop/Windowing/DesktopWindowManager.swift`
- Create: `iOS/Desktop/Windowing/DesktopWindowView.swift`
- Create: `iOS/Desktop/Windowing/DesktopWindowOverviewView.swift`

- [ ] **Step 1: Implement WindowSnapEngine for halves, quarters, thirds, and preview overlay**
- [ ] **Step 2: Implement DesktopWindowManager with z-ordering, tiling, and spatial animation tracking**
- [ ] **Step 3: Implement DesktopWindowView and DesktopWindowOverviewView**

---

### Task 7: Desktop Dock, Launcher, and Command Palette (`iOS/Desktop/Dock/` & `Apps/`)

**Files:**
- Create: `iOS/Desktop/Dock/DesktopDockView.swift`
- Create: `iOS/Desktop/Dock/DesktopAppLauncherView.swift`
- Create: `iOS/Desktop/Dock/DesktopCommandPaletteView.swift`

- [ ] **Step 1: Implement floating glass DesktopDockView with pinned/active/minimized items**
- [ ] **Step 2: Implement searchable DesktopAppLauncherView (Launchpad)**
- [ ] **Step 3: Implement Cmd+K DesktopCommandPaletteView**

---

### Task 8: Desktop Native & Web Applications (`iOS/Desktop/Apps/`)

**Files:**
- Create: `iOS/Desktop/Apps/Browser/DesktopBrowserState.swift`
- Create: `iOS/Desktop/Apps/Browser/DesktopBrowserView.swift`
- Create: `iOS/Desktop/Apps/ChatGPT/DesktopChatGPTView.swift`
- Create: `iOS/Desktop/Apps/YouTube/DesktopYouTubeView.swift`
- Create: `iOS/Desktop/Apps/Notes/DesktopNotesStore.swift`
- Create: `iOS/Desktop/Apps/Notes/DesktopNotesView.swift`
- Create: `iOS/Desktop/Apps/Files/DesktopFilesView.swift`
- Create: `iOS/Desktop/Apps/Files/DesktopPDFViewer.swift`
- Create: `iOS/Desktop/Apps/Takeover/PhoneTakeoverView.swift`

- [ ] **Step 1: Implement DesktopBrowser with tabs, URL navigation, and bookmarks**
- [ ] **Step 2: Implement ChatGPT and YouTube specialized containers**
- [ ] **Step 3: Implement native offline Notes store and editor**
- [ ] **Step 4: Implement native Files & PDF document viewer**
- [ ] **Step 5: Implement PhoneTakeoverView ("Continue on iPhone") for web logins**

---

### Task 9: External Display Coordinator & Root Views (`iOS/Desktop/Display/`)

**Files:**
- Create: `iOS/Desktop/Display/ExternalDisplayCoordinator.swift`
- Create: `iOS/Desktop/Display/ExternalDisplaySceneDelegate.swift`
- Create: `iOS/Desktop/Display/NoDisplayConnectedView.swift`
- Create: `iOS/Desktop/ExternalDesktopRootView.swift`
- Create: `iOS/Desktop/Debug/DesktopLabView.swift`
- Modify: `iOS/KamihiRemoteApp.swift`

- [ ] **Step 1: Implement ExternalDisplayCoordinator and iOS 27 scene delegate**
- [ ] **Step 2: Implement NoDisplayConnectedView and ExternalDesktopRootView**
- [ ] **Step 3: Implement DesktopLabView for side-by-side local Mac simulation**
- [ ] **Step 4: Update KamihiRemoteApp to wire AppModeRouter and root navigation**

---

### Task 10: Unit Self-Checks, Integration Tests & Smoke Verification (`iOS/Tests/`)

**Files:**
- Create: `iOS/Tests/DesktopRefactorTests.swift`
- Modify: `scripts/apple-integration-smoke.sh`

- [ ] **Step 1: Implement DesktopRefactorTests covering Router, Trackpad, Snapping, Browser, and Notes**
- [ ] **Step 2: Run HostIntegrationTest and DesktopRefactorTests**
- [ ] **Step 3: Build iOS Simulator app and macOS host**
- [ ] **Step 4: Run apple-integration-smoke.sh and inspect results**
