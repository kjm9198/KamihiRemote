# Focus 4 — Windowing / window management

Date: 2026-09-05

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: NOT READY.

The canonical `NATIVE_DESKTOP_GOAL.md` remains the authority: Kamihi is one persistent desktop, Remote-for-Mac stays retired, and older startup-profile/workspace roadmap language is compatibility history rather than normal-product direction.

The biggest overall software blocker remains native Sheets, because the readiness gate requires lightweight spreadsheet/table work in addition to Documents. Inside this rotation's window-management area, the highest-impact unfinished quality problem was reliable software-pointer ownership of the title-bar controls.

## CI triage before product work

- Pre-change `main`: `78c3aad7b491b074f4ca7d2c1774252d38a9be05`.
- Gmail: no current-head KamihiRemote failure; newest matching failure remained stale September 3 `2ef9c60` Apple Build / Apple Integration Smoke mail.
- Exact pre-change SHA checks: Apple Build `success`, Desktop Simulator Smoke `success`.
- No stale failure was treated as current.

## Focus 4 change

Product commit: `7613fffe1eadc87cd2f081c8c0724e28e38e5cb0` — `fix: harden desktop chrome pointer hit regions`.

`DesktopWindowChrome.action(at:in:)` now treats the trailing minimize / maximize-restore / close controls as one continuous software-pointer interaction cluster. The visual spacing remains, but the gaps are divided at their midpoints so aiming between adjacent icons resolves to the nearest intended control instead of becoming a dead region or leaking into title-bar behavior. The X target is also slightly more forgiving while actions remain mutually exclusive and deterministic.

This is especially important on glasses, where the external scene is noninteractive and all chrome actions are routed from the iPhone software pointer.

## Verification state at note creation

The exact product SHA started both Apple Build and Apple Integration/Desktop Simulator Smoke on original attempt 1. No rerun, retry, or harness workaround was used. Both workflows were still in progress when this note was written, so the product batch must not be described as fully verified until those exact-SHA checks complete.

Desktop Lab screenshot review is not required for this geometry-only hit-testing change because rendered chrome did not change. The existing deterministic Desktop Window Chrome Hit Testing self-check and exact-SHA build/simulator integration smoke are the relevant software evidence.

## Next rotation

Focus 5 — phone controller ergonomics. Select the highest-impact unfinished readiness blocker in that area; do not add novelty while a core controller usability blocker remains.

## Physical-only checks

NEEDS PHYSICAL TEST: actual RayNeo Air 4 Pro negotiated resolution/refresh, overscan/readability, USB-C unplug/reconnect, end-to-end pointer/hold-to-move feel and latency, Bluetooth keyboard/mouse, real Password AutoFill/passkeys/CAPTCHA/file picker flows, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
