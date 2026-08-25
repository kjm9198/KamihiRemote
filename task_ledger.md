# Kamihi Remote v0.4 Task Ledger & Verification Matrix

| Area | Feature / Requirement | Status | Notes / Evidence |
| :--- | :--- | :--- | :--- |
| **Multi-Touch** | 1 Finger Tracking & Acceleration | AUTOMATED TESTED | dt-independent scaling; verified in `GestureEngineTests.oneFingerMove` |
| **Multi-Touch** | 2 Finger Contact & Secondary Click | AUTOMATED TESTED | Verified in `GestureEngineTests.twoFingerTap` -> `.rightClick` |
| **Multi-Touch** | 3 Finger Contact & Look Up / Tap | AUTOMATED TESTED | Verified in `GestureEngineTests.threeFingerTap` -> `.shortcut("cmd+ctrl+d")` |
| **Multi-Touch** | 4 Finger Contact | AUTOMATED TESTED | Verified in `GestureEngineTests.fourFinger` -> `.system` actions |
| **Multi-Touch** | Async Finger Lift Preservation | AUTOMATED TESTED | Fixed 3->2->1->0 async lift bug; verified in `GestureEngineTests.asyncThreeFingerRelease` |
| **Multi-Touch** | Cumulative Gesture Recognition | AUTOMATED TESTED | Tested with small frame deltas in `GestureEngineTests.threeFingerCumulative` |
| **Animation** | Stable Finger IDs | AUTOMATED TESTED | Keyed by persistent `finger.id` in `TouchAnimationState` & `TouchAnimationView` |
| **Animation** | Liquid Glass 1-Finger Orb & Squish | IMPLEMENTED | Interactive spring, tap squish, double-tap ripples, drag lock |
| **Animation** | 2-Finger Metaball Bridge & Flow | IMPLEMENTED | Translucent bridge with distance tension & directional flow |
| **Animation** | 3/4-Finger Group Shear & Glow | IMPLEMENTED | Directional group shear & aura deformation for swipe candidates |
| **Animation** | Reduce Motion Support | IMPLEMENTED | `accessibilityReduceMotion` eliminates heavy morphs & floating animation |
| **Scroll** | Frame-rate Independent Physics | AUTOMATED TESTED | $e^{-\lambda \cdot dt}$ decay verified within 8% at simulated 60Hz vs 120Hz in `GestureEngineTests.frameRateIndependence` |
| **Scroll** | Rolling Weighted Velocity History | AUTOMATED TESTED | 80ms weighted sample window in `ScrollGestureEngine.estimateReleaseVelocity` |
| **Scroll** | Immediate Momentum Cancellation | AUTOMATED TESTED | Verified in `ScrollGestureEngine.begin` -> `.momentumEnded` |
| **Scroll** | Axis Damping & Natural Scaling | AUTOMATED TESTED | Axis locking with 0.15 damping in `ScrollGestureEngine.scrollMoved` |
| **Gestures** | 3-Finger Swipe Up (Mission Control) | AUTOMATED TESTED | Verified in `GestureEngineTests.asyncThreeFingerRelease` |
| **Gestures** | 3-Finger Swipe Down (App Exposé) | AUTOMATED TESTED | Verified in `GestureEngineTests.threeFingerCumulative` |
| **Gestures** | 3-Finger Swipe Left/Right (Spaces) | AUTOMATED TESTED | Verified in `GestureEngineTests.threeFingerCumulative` |
| **Gestures** | 4-Finger Swipe Mappings | AUTOMATED TESTED | Verified in `GestureEngineTests.fourFinger` |
| **Layout** | Landscape Safe Area & Dynamic Island | IMPLEMENTED | Tested across portrait, landscape, and iPad layouts in `RootView.swift` |
| **Layout** | PointerPad in All Modes | IMPLEMENTED | Reusable `ModeShell` / `TrackpadCanvas` in all remote tabs |
| **Presentation** | Slides Control & Profiles | IMPLEMENTED | Keynote, PowerPoint, and Generic profiles in `PresentationScreen` |
| **Presentation** | Laser Pointer Overlay | IMPLEMENTED | Live coordinate mapping in `LaserOverlay.swift` & `RemoteCommand.laser` |
| **Keyboard** | Modifiers & Key Combinations | IMPLEMENTED | Sticky modifier flags & safe release on disconnect/background |
| **Keyboard** | Mirrored Mac Text Editing | BUILD TESTED | Append/delete fast paths plus deterministic full-field replacement for divergent/mid-field edits in `KeyboardOverlayDock` |
| **Media** | System Media Keys | IMPLEMENTED | MediaAction wire encoding & InputEngine integration |
| **Deck** | Real macOS App Picker | IMPLEMENTED | Enumerate `/System/Applications`, `/Applications`, `~/Applications` |
| **Deck** | Real Actions (URL, App, Shortcut) | IMPLEMENTED | `NSWorkspace.OpenConfiguration` with `activates = true` in `AppCatalog.swift` |
| **Security** | Authenticated AES-GCM MOVE Traffic | AUTOMATED TESTED | `K3` protocol verified with CryptoKit AES-GCM, tag validation, & corruption rejection in `RemotePacket.runSelfChecks()` |
| **Security** | Pairing & Keychain Secret Storage | AUTOMATED TESTED | PIN/QR handshake + Curve25519 ECDH verified in `SessionCrypto.runSelfChecks()` |
| **Security** | Device Revocation | IMPLEMENTED | `HostSession.revokeDevice` removes peer & resets connections |
| **Transport** | Connection State Machine & Reconnect | IMPLEMENTED | Scheduled exponential backoff reconnects in `RemoteSession.swift` |
| **Transport** | Preserve Queued Commands Across Reconnect | IMPLEMENTED | `ReliableClient.connect` now preserves commands queued while TCP is down; explicit user stop still clears them |
| **Transport** | Direct Wi-Fi & LAN Network.framework | IMPLEMENTED | `NWParameters.includePeerToPeer = true` across TCP and UDP |
| **Transport** | CoreBluetooth (BLE) Transport | PLANNED / PLACEHOLDER | UUIDs and placeholder status types exist, but there is not yet a working scanner, peripheral, characteristic subscription, authentication, or command data path |
| **Controller** | Simultaneous Touches & Snapshot | IMPLEMENTED | Compact state snapshot serialization in `RemoteCommand.controller` |
| **Air Mouse** | CoreMotion IMU Tracking | IMPLEMENTED | IMU tracking & sensitivity configuration in `TouchInputEngine` & `AppPreferences` |
| **Verification** | Native iOS + macOS CI | AUTOMATED TESTED | `.github/workflows/native-ci.yml` runs protocol/crypto self-checks, builds both native schemes, then runs iPhone simulator UI smoke captures |
