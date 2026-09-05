# Focus 1 — External-display / RayNeo fidelity

Date: 2026-09-05

## Readiness verdict

NOT READY. Current software still has unfinished readiness gates and requires physical RayNeo validation.

## Start-of-run triage

- Gmail: no current-head KamihiRemote failure; newest relevant failures remain stale September 3 `2ef9c60` Apple Build / Apple Integration Smoke mail.
- Pre-change main: `25c7ac21a65fc5bff2ae1db99205563b335f4b8f`.
- Pre-change Apple Build: success on attempt 1.
- Pre-change Desktop Simulator Smoke: success on attempt 1.
- No rerun or CI harness work was needed.

## Highest-impact blocker inside Focus 1

Kamihi already supports per-edge RayNeo safe-area calibration through left/right/top/bottom trim values, and those trims correctly move desktop content inward. However, the external calibration guide and calibrated-canvas border only stayed visible when the older symmetric horizontal/vertical margins were nonzero. An asymmetric-only calibration therefore remained active while its persistent visual reference disappeared after the temporary eight-second display-check overlay expired.

That makes real glasses calibration unnecessarily error-prone because a user tuning a single clipped edge can lose the reference even though the asymmetric trim is still affecting the desktop.

## Change

Product commit: `205bc24308c7d6241325f75c7c9a02758c254f67` — `fix: keep asymmetric display calibration visible`.

- External desktop calibration visibility now uses the coordinator's canonical `hasCalibration` state.
- The calibrated-canvas border remains visible for symmetric or asymmetric calibration.
- The full display-check guide remains visible while any persisted calibration is active, including left/right/top/bottom trims.
- No display mode, refresh rate, pointer, window, WebKit, or remote-host behavior changed.
- Kamihi still only observes the resolution/refresh iOS negotiates and never claims it can force 120 Hz.

## Verification

Exact product SHA `205bc24308c7d6241325f75c7c9a02758c254f67`:

- Apple Build: success on original attempt 1.
- Apple Integration Smoke / Desktop Simulator Smoke: success on original attempt 1.
- Trackpad-first controller contract: passed.
- Full Kamihi Desktop simulator smoke: passed.
- Smoke evidence upload: passed.
- No rerun, retry, or harness workaround was used.

This is a two-condition calibration-state fix rather than a new layout/input surface. The standard integration smoke produced its evidence successfully; no separate Desktop Lab screenshot comparison was required for this conditional state change.

## Top remaining software blocker

Native daily-use productivity completeness remains the largest software blocker, particularly making Sheets import/export directly reachable in the normal controller/file-picker workflow and improving spreadsheet editing beyond basic cell-by-cell entry.

## Next focus

Focus 2 — iPadOS-style shell/design system. Choose the highest-impact unfinished shell/readability/accessibility blocker rather than novelty work.

## Physical-only checks — NEEDS PHYSICAL TEST

- actual negotiated RayNeo Air 4 Pro resolution and refresh,
- glasses overscan/readability and black levels,
- USB-C unplug/reconnect,
- end-to-end pointer latency and feel,
- deliberate hold-to-move window feel,
- Bluetooth keyboard/mouse,
- Password AutoFill/passkeys/CAPTCHA/file picker on real services,
- YouTube/ChatGPT login/playback,
- long-session battery/thermal behavior.
