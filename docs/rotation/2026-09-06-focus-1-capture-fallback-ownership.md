# Focus 1 — External-display fallback capture ownership

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: NOT READY. The current canonical goal is the one persistent iPhone desktop; Remote-for-Mac and user-facing startup profiles remain retired. The largest overall software-readiness blocker remains richer native productivity behavior, especially Sheets range workflows, while this rotation addressed an external-display reconnect integrity gap.

## Failure triage

The newest Gmail failures are for older SHA `76fd692`; current baseline `274654e` has Apple Build and Apple Integration Smoke green on attempt 1. No current-head CI failure blocked feature work.

## Focus 1 finding

Fast USB-C replacement can temporarily leave more than one external-display scene alive. Kamihi already protected shared connection state and display metrics from stale scene callbacks, but `DesktopCaptureService` held only the newest scene window. If that newest scene disconnected and Kamihi fell back to an older still-live external scene, negotiated metrics recovered while desktop capture remained detached.

## Change

Product commit: `07d6ba082d462d225f32459a310993ce89a12ee1` — `fix: restore capture ownership on display fallback`.

- Live-scene fallback state now retains the corresponding external `UIWindow` together with public UIKit screen/logical-size metrics.
- When the primary external scene disappears while another scene remains, Kamihi reattaches `DesktopCaptureService` to the fallback window before refreshing shared metrics.
- Geometry updates keep the live scene window paired with its latest metrics.
- No Mac-host, pairing, network-control, profile, refresh-forcing, or display-mode-selection path was introduced.

## Verification

At note creation, Apple Build and Apple Integration Smoke for the product SHA are running on original attempt 1 with no rerun/retry/harness workaround. Trackpad-first integration setup is green and the full simulator/build gates are still executing.

Desktop Lab screenshot comparison is not independently useful for this lifecycle-only change because visible canvas geometry and UI are unchanged.

## Remaining physical-only checks

NEEDS PHYSICAL TEST: actual RayNeo Air 4 Pro negotiated resolution/refresh, overscan/readability, rapid USB-C unplug/reconnect including overlapping replacement scenes, end-to-end pointer/window feel, Bluetooth keyboard/mouse, real-service Password AutoFill/passkeys/CAPTCHA/file picker, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

## Next rotation

Focus 2 — iPadOS-style shell/design system, selecting the highest-impact unfinished readiness blocker inside that area after exact-head failure triage.