# Kamihi Remote v0.4 Task Ledger & Verification Matrix

| Area | Feature / Requirement | Status | Notes / Evidence |
| :--- | :--- | :--- | :--- |
| **Multi-Touch** | 1 Finger Tracking & Acceleration | AUTOMATED TESTED | dt-independent scaling; verified in `GestureEngineTests.oneFingerMove` |
| **Multi-Touch** | 2 Finger Contact & Secondary Click | AUTOMATED TESTED | Verified in `GestureEngineTests.twoFingerTap` -> `.rightClick` |
| **Multi-Touch** | 3 Finger Contact & Look Up / Tap | AUTOMATED TESTED | Verified in `GestureEngineTests.threeFingerTap` -> `.shortcut("cmd+ctrl+d")` |
| **Multi-Touch** | 4 Finger Contact | AUTOMATED TESTED | Verified in `GestureEngineTests.fourFinger` -> `.system` actions |
| **Multi-Touch** | Async Finger Lift Preservation | AUTOMATED TESTED | Fixed 3->2->1->0 async lift bug; verified in `GestureEngineTests.asyncThreeFingerRelease` |
| **Cumulative Gesture Recognition** | Small frame deltas | AUTOMATED TESTED | Tested in `GestureEngineTests.threeFingerCumulative` |
| **Animation** | Stable Finger IDs | AUTOMATED TESTED | Keyed by persistent `finger.id` in `TouchAnimationState` & `TouchAnimationView` |
| **Animation** | Liquid Glass 1-Finger Orb & Squish | IMPLEMENTED | Interactive spring, tap squish, double-tap ripples, drag lock |
| **Animation** | 2-Finger Metaball Bridge & Flow | IMPLEMENTED | Translucent bridge with distance tension & directional flow |
| **Animation** | 3/4-Finger Group Shear & Glow | IMPLEMENTED | Directional group shear & aura deformation for swipe candidates |
| **Animation** | Reduce Motion Support | IMPLEMENTED | `accessibilityReduceMotion` eliminates heavy morphs & floating animation |
| **Scroll** | Frame-rate Independent Physics | AUTOMATED TESTED | Exponential decay verified at simulated 60Hz vs 120Hz |
| **Scroll** | Rolling Weighted Velocity History | AUTOMATED TESTED | 80ms weighted sample window in `ScrollGestureEngine.estimateReleaseVelocity` |
| **Scroll** | Immediate Momentum Cancellation | AUTOMATED TESTED | Verified in `ScrollGestureEngine.begin` |
| **Scroll** | Axis Damping & Natural Scaling | AUTOMATED TESTED | Axis locking with 0.15 damping |
| **Gestures** | 3-Finger Swipe Up (Mission Control) | AUTOMATED TESTED | Verified in gesture tests |
| **Gestures** | 3-Finger Swipe Down (App Exposé) | AUTOMATED TESTED | Verified in gesture tests |
| **Gestures** | 3-Finger Swipe Left/Right (Spaces) | AUTOMATED TESTED | Verified in gesture tests |
| **Gestures** | 4-Finger Swipe Mappings | AUTOMATED TESTED | Verified in gesture tests |
| **Layout** | Landscape Safe Area & Dynamic Island | IMPLEMENTED | Tested across portrait, landscape, and iPad layouts in `RootView.swift` |
| **Layout** | PointerPad in All Modes | IMPLEMENTED | Reusable `ModeShell` / `TrackpadCanvas` in all remote tabs |
| **Presentation** | Slides Control & Profiles | IMPLEMENTED | Keynote, PowerPoint, and Generic profiles |
| **Presentation** | Laser Pointer Overlay | IMPLEMENTED | Live coordinate mapping |
| **Keyboard** | Modifiers & Key Combinations | IMPLEMENTED | Sticky modifier flags & safe release |
| **Media** | System Media Keys | IMPLEMENTED | MediaAction wire encoding & InputEngine integration |
| **Deck** | Real macOS App Picker | IMPLEMENTED | Enumerate installed applications |
| **Deck** | Real Actions (URL, App, Shortcut) | IMPLEMENTED | NSWorkspace launch support |
| **Security** | Authenticated AES-GCM MOVE Traffic | AUTOMATED TESTED | K3 protocol verified with CryptoKit |
| **Security** | Pairing & Keychain Secret Storage | AUTOMATED TESTED | PIN/QR handshake + Curve25519 ECDH |
| **Security** | Device Revocation | IMPLEMENTED | Removes peer & resets connections |
| **Transport** | Connection State Machine & Reconnect | IMPLEMENTED | Exponential backoff reconnects |
| **Transport** | Preserve Queued Commands Across Reconnect | IMPLEMENTED | Commands survive temporary TCP loss |
| **Transport** | Direct Wi-Fi & LAN Network.framework | IMPLEMENTED | `NWParameters.includePeerToPeer = true` |
| **Transport** | CoreBluetooth (BLE) Transport | NOT IMPLEMENTED | UUID constants exist, but no complete transport |
| **Controller** | Simultaneous Touches & Snapshot | IMPLEMENTED | Compact state snapshot serialization |
| **Air Mouse** | CoreMotion IMU Tracking | IMPLEMENTED | IMU tracking & sensitivity configuration |

---

# GOAL: Kamihi Desktop Mode for iPhone External Displays

## Product Goal

Turn KamihiRemote into a desktop-style environment whenever an iPhone is connected to an external display. The external display becomes the workspace and the iPhone becomes its trackpad, keyboard and control surface. This must be an additive feature: normal KamihiRemote functionality must continue working when no external display is connected.

This is a Kamihi-owned desktop shell, not an attempt to bypass iOS restrictions or window arbitrary third-party iPhone applications. Native Apple frameworks should be used wherever possible so built-in Kamihi apps feel native.

## Non-Negotiable Safety Rules

- Do not remove or regress existing Remote mode functionality.
- Keep the existing shared `RemoteSession` architecture intact unless a change is demonstrably required.
- External-display connection/disconnection must never crash or strand the phone UI.
- Desktop mode must remain usable if the Mac host is unavailable.
- No private Apple APIs.
- No attempts to embed or control arbitrary third-party iOS apps.
- Respect accessibility settings including Reduce Motion and Dynamic Type where applicable.
- Add automated tests for state/window/input logic that can be tested without physical hardware.
- Physical external-display behavior must have a documented manual verification matrix.

## Phase 1 — External Display Foundation

| Requirement | Target |
| :--- | :--- |
| Detect external display connection | TODO |
| Detect external display disconnection | TODO |
| Create dedicated external-display scene/window | TODO |
| Keep normal iPhone UI on phone | TODO |
| Automatically enter Desktop Controller mode on phone | TODO |
| Return cleanly to normal Remote UI after disconnect | TODO |
| Handle reconnect and orientation/resolution changes | TODO |
| Support different external aspect ratios and safe areas | TODO |

## Phase 2 — Desktop Shell

Build `Desktop/` as an isolated subsystem with a clear model/view/input separation.

Suggested components:

- `ExternalDisplayManager`
- `KamihiDesktopView`
- `DesktopSession`
- `DesktopWindowModel`
- `DesktopWindowManager`
- `DesktopInputRouter`
- `DesktopCursor`
- `DesktopTaskbar`
- `DesktopLauncher`
- `DesktopAppRegistry`

Required behavior:

| Requirement | Target |
| :--- | :--- |
| Desktop wallpaper/background | TODO |
| Top/status area with clock and connection state | TODO |
| Bottom dock/taskbar | TODO |
| App launcher | TODO |
| Software cursor | TODO |
| Active-window focus | TODO |
| Multiple Kamihi windows | TODO |
| Drag windows | TODO |
| Resize windows | TODO |
| Minimize | TODO |
| Maximize/restore | TODO |
| Close | TODO |
| Snap left/right | TODO |
| Correct z-order | TODO |
| Remember reasonable window positions during session | TODO |
| Smooth animations with Reduce Motion fallback | TODO |

## Phase 3 — iPhone Becomes the Laptop Controller

Reuse the existing KamihiRemote gesture and keyboard infrastructure instead of creating a competing gesture engine.

Desktop mapping:

- One-finger movement -> desktop cursor.
- Tap -> primary click.
- Double tap -> double click/open.
- Tap-drag -> drag window/item.
- Two-finger movement -> scroll.
- Two-finger tap -> context/right click.
- Pinch -> zoom where the active desktop app supports it.
- Three-finger swipe up -> desktop overview/app switcher.
- Three-finger left/right -> switch active desktop app/window where appropriate.
- Keyboard button -> native iPhone keyboard input routed to focused desktop app.
- Dedicated Command/Option/Control/Shift controls for desktop shortcuts.

The phone controller should be extremely simple while Desktop Mode is active: connection indicator, large trackpad, keyboard button, app/overview button and quick controls. It must remain accessible one-handed where possible.

## Phase 4 — Native-Feeling Kamihi Desktop Apps

Do not clone Apple apps pixel-for-pixel. Build Kamihi apps backed by public native frameworks.

### Browser
- WebKit-based browser window.
- Address/search field.
- Back, forward and reload.
- Multiple tabs after the single-tab implementation is stable.
- Desktop-size responsive layout.

### Files
- Public document/file picker APIs.
- Recents and user-selected documents where platform permissions allow.
- Quick Look previews.
- Never imply unrestricted filesystem access.

### Photos
- PhotoKit with explicit user permission.
- Grid and image preview.
- Respect limited-library permissions.

### Notes
- Lightweight local Kamihi notes.
- Autosave.
- Keyboard-first editing.

### Calculator
- Fast native calculator suitable for desktop window use.

### Settings
- Display information.
- UI scaling.
- Cursor speed.
- Scroll direction/sensitivity.
- Wallpaper selection.
- Reduce animations option in addition to system accessibility behavior.

### Later Native Utilities
- PDFKit PDF viewer.
- Quick Look document preview.
- AVFoundation media player.
- Share-sheet integration.
- Clipboard actions allowed by iOS.

## Phase 5 — Desktop UX Polish

- Window shadows and clear active-window state.
- Large accessible resize targets even when visual handles are subtle.
- Keyboard navigation.
- Focus indicators.
- Sensible minimum window sizes.
- Dock running-app indicators.
- Desktop overview / Mission Control-like screen.
- Context menus.
- App switcher.
- Full-screen window mode.
- Restore gracefully after external display reconnect where practical.
- Avoid excessive glass/blur effects that reduce readability.

## Phase 6 — Optional KamihiRemote Integration

Only after the local desktop is reliable:

- A Remote Desktop Kamihi app/window for paired Mac/PC hosts.
- Project launcher.
- Dictation -> transcription -> selected development tool workflow.
- Remote app launcher using existing authenticated KamihiRemote transport.
- Clipboard transfer where safe and explicitly initiated.

Remote-host availability must never be required for the local Kamihi Desktop shell to start.

## Definition of Done — Desktop V1

Desktop V1 is complete only when all of the following are true:

1. Connect a supported external display and Kamihi Desktop appears without requiring navigation through settings.
2. The iPhone remains on a dedicated controller interface rather than mirroring the desktop UI.
3. Cursor movement, click, double click, drag, right click and scrolling work reliably.
4. At least two Kamihi windows can be open simultaneously.
5. Windows can move, resize, minimize, maximize, restore, close and snap.
6. Dock/taskbar and launcher work.
7. Browser, Files, Notes, Calculator and Settings open as real functional Kamihi apps.
8. Keyboard text entry reaches the focused desktop app correctly.
9. Disconnecting the display returns the iPhone to normal KamihiRemote without a restart.
10. Reconnecting starts a valid fresh/restored Desktop session without duplicate windows/scenes.
11. Existing KamihiRemote remote-control functionality still passes its existing tests.
12. Window/input state logic has automated test coverage.
13. A physical-device test is completed using at least one wired external display configuration.
14. Layout is checked at common 16:9 resolutions and at least one non-16:9 output.
15. No private APIs, secrets, unsafe entitlements or system-app impersonation are introduced.

## Verification Matrix

Before calling Desktop V1 complete, record PASS/FAIL for:

- iPhone launch without monitor.
- Plug monitor in while app is open.
- Launch app while monitor is already attached.
- Unplug monitor while windows are open.
- Reconnect monitor.
- Background/foreground app with monitor attached.
- Lock/unlock iPhone with monitor attached.
- Change monitor resolution/orientation where available.
- Cursor movement at slow and fast speeds.
- Click/double-click/right-click.
- Drag without accidental click release.
- Long continuous two-finger scroll and momentum cancellation.
- Keyboard show/hide and focused text entry.
- Modifier shortcuts.
- Open two or more windows.
- Resize to minimum bounds.
- Snap/maximize/restore/minimize/close.
- Browser navigation.
- Notes autosave.
- Files permission/document picker behavior.
- Accessibility Reduce Motion.
- Existing Remote mode regression suite.

## Immediate Implementation Milestone

Start with a vertical slice rather than building every app at once:

1. External display lifecycle.
2. Basic desktop scene.
3. Phone switches to Desktop Controller.
4. Software cursor driven by existing pointer input.
5. One movable/resizable test window.
6. Dock with one Browser icon.
7. Browser window using WebKit.
8. External-display disconnect/reconnect recovery.
9. Automated tests for `DesktopWindowManager` and input routing.
10. Physical-device verification before expanding to Files/Photos/Notes.

Only after this vertical slice is stable should the implementation expand into the complete Desktop V1 feature set.