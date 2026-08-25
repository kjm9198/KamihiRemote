# 3-Finger Gesture & Desktop Switching Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make 3-finger swipe left/right on iPhone reliably switch macOS Desktops/Spaces, and prove each stage of the pipeline (recognized, transmitted, received, injected, and verified Space change).

**Architecture:** 
1. **iOS Touch Pipeline:** Use cumulative centroid delta (`currentCentroid - startCentroid`) with a 32–40pt threshold and 1.25x axis bias to lock 3-finger horizontal/vertical swipes. Protect locked swipes against transient finger drops (`3 -> 2`) until all fingers lift, and prevent multiple triggers during a single swipe.
2. **Deterministic Diagnostics:** Display live developer HUD showing UIKit touch count, gesture state, start/current centroids, cumulative dx/dy, locked axis, direction, command, and TCP ACK state.
3. **Mac Injection & Verification:** Simplify Mac Desktop switching to a single `Control + Arrow` CGEvent using the system event source; remove automatic duplicate AppleScript. Register `NSWorkspace.activeSpaceDidChangeNotification` observer *before* posting the key event with a 1.0s timeout.
4. **Deterministic Test Buttons:** Add Mac-local test buttons (`TEST DESKTOP ←/→`, `TEST MISSION CONTROL`, `TEST APP EXPOSÉ`) and iPhone TCP command test buttons (`SEND DESKTOP ←/→`, `SEND MISSION CONTROL`) to cleanly split local vs network vs gesture failures.

**Tech Stack:** Swift, SwiftUI, AppKit, UIKit, CoreGraphics CGEvents, NSWorkspace notifications, Network framework (TCP/UDP).

---

## Proposed Changes

### iOS Layer
#### [MODIFY] [GestureEngine.swift](file:///Users/kjm9198/KamihiRemote/iOS/GestureEngine.swift)
- Replace frame-by-frame velocity thresholds with cumulative centroid delta from `startCentroid`.
- Apply distance threshold (32–40pt) with axis bias (1.25x) to lock `.threeFingerSwipe`.
- Ensure sticky 3-finger state survives brief finger drops until `remaining == 0` without re-triggering.
- Enforce single `SystemAction` emission per gesture via `didEmitSwipe`.
- Ensure single-finger tap strictly performs left click / tap and never triggers options / right-click.

#### [MODIFY] [TouchInputEngine.swift](file:///Users/kjm9198/KamihiRemote/iOS/TouchInputEngine.swift) & [PolishedV04UI.swift](file:///Users/kjm9198/KamihiRemote/iOS/PolishedV04UI.swift)
- Enhance Developer Diagnostics HUD on iPhone to show live 3-finger pipeline metrics: UIKit touches, gesture fingers, state, start/current centroid, cumulative dx/dy, axis, direction, locked status, generated command, TCP status.
- Add test buttons to trigger raw TCP system commands directly (`SEND DESKTOP ←`, `SEND DESKTOP →`, `SEND MISSION CONTROL`).

#### [MODIFY] [GestureEngineTests.swift](file:///Users/kjm9198/KamihiRemote/iOS/GestureEngineTests.swift)
- Add comprehensive TDD tests for:
  - `threeFingerLeftSmallFrames`
  - `threeFingerRightSmallFrames`
  - `threeFingerUpSmallFrames`
  - `threeFingerDownSmallFrames`
  - `threeFingerDropOneFingerStaysLocked`
  - `threeFingerSingleTriggerOnly`
  - Single tap left click regression vs two finger right click.

### macOS Host Layer
#### [MODIFY] [InputEngine.swift](file:///Users/kjm9198/KamihiRemote/macOS/InputEngine.swift)
- Fix `performDesktop`: Register observer with `SpaceChangeVerifier` *before* posting key event.
- Fix event generation: Use `source = CGEventSource(stateID: .hidSystemState)` and post `keyDown` + `keyUp` with `.maskControl`.
- Remove automatic duplicate AppleScript invocation.
- Return detailed diagnostic string on success/failure.

#### [MODIFY] [SpaceChangeVerifier.swift](file:///Users/kjm9198/KamihiRemote/macOS/SpaceChangeVerifier.swift)
- Update to support pre-registration: `begin()` returns an observer handle before posting event, and `await handle.wait(timeout: 1.0)` awaits the notification.

#### [MODIFY] [HostView.swift](file:///Users/kjm9198/KamihiRemote/macOS/HostView.swift)
- Add Mac Host Diagnostics test buttons:
  - `TEST DESKTOP ←`
  - `TEST DESKTOP →`
  - `TEST MISSION CONTROL`
  - `TEST APP EXPOSÉ`
- Display detailed diagnostic results: Accessibility trusted, CGEvent created/posted, Space notification received, PASS / FAIL with troubleshooting tips.

---

## Verification Plan

### Automated Tests
- Run `GestureEngineTests.runAll()` via swift test script / xcodebuild test.
- Verify cumulative small frame sweeps, sticky finger drops, single triggers, and pointer/scroll isolation.

### Manual & Physical Verification
1. **Level 1 (Mac Only):**
   - Check physical `Control + Left/Right Arrow` switches Spaces.
   - Run Mac Host `TEST DESKTOP →` button; verify Space switches and `RESULT: PASS` appears.
   - Run Mac Host `TEST DESKTOP ←` button; verify Space switches and `RESULT: PASS` appears.
2. **Level 2 (iPhone Network Command):**
   - Press iPhone Debug `SEND DESKTOP →`; verify Mac receives TCP packet, injects `Control+Right`, Space switches, and ACK returns `Desktop → ✓`.
3. **Level 3 (iPhone 3-Finger Gesture):**
   - Perform physical 3-finger swipe right on iPhone 17 (`kjm9198`); verify HUD shows 3 touches, cumulative dx > 35, locks horizontal right, emits `nextDesktop`, and Mac switches Space.
   - Perform physical 3-finger swipe left; verify `previousDesktop` switches Space left.
   - Perform physical 3-finger swipe up; verify Mission Control opens.
4. **Regression Verification:**
   - 1 finger moves pointer smoothly.
   - 1 finger tap clicks (never triggers options).
   - 2 fingers scroll smoothly.
   - 2 finger tap triggers secondary click / right click.
