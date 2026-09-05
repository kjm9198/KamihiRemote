# Focus 1 — External-display reconnect scene ownership

Date: 2026-09-05

## Readiness finding

Kamihi Desktop is **NOT READY** for full RayNeo sign-off because physical validation is still required and native Sheets remains incomplete for daily spreadsheet use. Within Focus 1, the highest-impact software risk found in this run was external-display reconnect ownership.

The canonical product model remains one persistent desktop. Legacy startup-profile wording is superseded by `NATIVE_DESKTOP_GOAL.md`; do not restore user-facing Clean/Resume/Work/Browse/Media/Vibe selection.

## Problem

During a fast USB-C unplug/replug, iOS may briefly overlap a retiring external-display scene with its replacement. The shared `ExternalDisplayCoordinator` previously had only one boolean connection state. A delayed `sceneDidDisconnect` from the old scene could therefore call `disconnect()` after the new scene had already connected, incorrectly switching the iPhone out of the connected desktop/controller state while a valid external scene remained live.

## Change

Product commit `908ee0c47f05dcafa74d067a94e0ba22c0112976` adds process-local ownership of live external scene session identifiers in `ExternalDisplaySceneDelegate`.

- Each external scene registers its `UISceneSession.persistentIdentifier` when connected.
- Disconnect removes only that scene identifier.
- The shared desktop is marked disconnected only when the last registered external scene is gone.
- Desktop window state is still saved on each scene retirement.
- `DesktopCaptureService` already detaches by UIWindow identity, so a stale retiring scene cannot detach the replacement capture window.
- No Mac-host pairing/networking/remote-control path was exposed or restored.

## Verification

Pre-change `main` `bfa985675c3e3e9516b126e2b4662400085a29b5` had Apple Build and Desktop Simulator Smoke green. Product SHA `908ee0c47f05dcafa74d067a94e0ba22c0112976` started both required workflows on original attempt 1. At the time this note was recorded, both were still in progress; do not call the batch verified until both complete successfully on attempt 1.

No Desktop Lab visual comparison was required because the change affects scene lifecycle ownership only and does not alter rendered UI or input geometry.

## Remaining physical-only checks

NEEDS PHYSICAL TEST on a real iPhone + RayNeo Air 4 Pro/external monitor: negotiated resolution/refresh, overscan/readability, rapid USB-C unplug/replug, end-to-end pointer latency/feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

Next rotation: Focus 2 — iPadOS-style shell/design system.