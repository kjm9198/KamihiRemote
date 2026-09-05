# Focus 1 — External-display / RayNeo fidelity

Date: 2026-09-05

## Readiness verdict

NOT READY. Current software head still needs the remaining readiness gates and physical RayNeo validation.

## Start-of-run triage

- Gmail: no current-head KamihiRemote failure; newest relevant failures remain stale September 3 `2ef9c60` Apple Build / Apple Integration Smoke mail.
- Pre-change main: `d4cc8225f1625e91268793277570f60e0e6c5c52`.
- Pre-change Apple Build: success.
- Pre-change Desktop Simulator Smoke: success.
- Smoke passed on the first attempt; no rerun/harness work was needed.

## Highest-impact blocker inside Focus 1

The external UIWindow was already sized from `UIWindowScene.coordinateSpace.bounds`, but `ExternalDisplayCoordinator` still recorded logical UIKit geometry from `UIScreen.bounds`. iOS can expose scene geometry that differs after external-display negotiation or overscan/coordinate-space updates. That meant Kamihi could render into one logical canvas while diagnostics, backing-scale alignment checks, and RayNeo calibration reasoning used another.

## Change

Feature commits: `e3e847a8a818623ef7614f5f04209daf1db60ec6` and `95872656800e28bab239b795b23ad2553f05da60`.

- `ExternalDisplayCoordinator.connect` and `refreshMetrics` now accept the actual external scene logical size.
- `ExternalDisplaySceneDelegate` passes `windowScene.coordinateSpace.bounds.size` both on first connection and on negotiated-geometry updates.
- Native pixel dimensions are orientation-aligned to the logical scene before backing-scale comparisons, avoiding false X/Y scale mismatches when UIKit and `nativeBounds` report opposite orientation conventions.
- Kamihi still observes only the mode and maximum refresh rate iOS exposes. It does not force a display mode or claim it can force 120 Hz.

## Verification

Exact source head `95872656800e28bab239b795b23ad2553f05da60` entered Apple Build and Desktop Simulator Smoke on original attempt 1. At documentation time both were queued; no retries or harness workaround were used.

No significant UI layout/input surface changed, so Desktop Lab screenshot comparison is not required for this geometry-plumbing batch. Simulator/build CI remains the software verification path; negotiated resolution/overscan still require physical hardware.

## Next focus

Focus 2 — iPadOS-style shell/design system. Overall top software blocker remains native Sheets, but rotation should continue to the highest-impact unfinished shell blocker before returning to native apps.

## Physical-only checks — NEEDS PHYSICAL TEST

- actual negotiated RayNeo Air 4 Pro resolution and refresh,
- glasses overscan/readability and black levels,
- USB-C unplug/reconnect,
- end-to-end pointer latency and deliberate hold-to-move feel,
- Bluetooth keyboard/mouse,
- Password AutoFill/passkeys/CAPTCHA/file picker on real services,
- YouTube/ChatGPT login/playback,
- long-session battery/thermal behavior.
