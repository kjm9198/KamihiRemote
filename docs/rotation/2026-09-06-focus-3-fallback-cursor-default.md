# Focus 3 — Trackpad / Pointer Readiness

## Readiness audit

Current product direction follows `NATIVE_DESKTOP_GOAL.md`: one persistent iPhone desktop, no user-facing startup profiles, and no Remote-for-Mac product path.

Top overall software blocker remains everyday productivity depth, especially richer Sheets range/multi-cell workflows. Inside Focus 3, the pointer quality gap addressed in this run was inconsistent cursor fallback behavior: `TrackpadSettings` defaults untouched installations to the high-contrast Classic Arrow, but `DesktopCursorView` still defaulted to the older Kamihi Dot whenever a caller omitted an explicit style.

## Change

- `DesktopCursorView` now defaults to `.classicArrow`, matching `TrackpadSettings`.
- This keeps fallback/debug/Desktop Lab surfaces aligned with the production pointer default instead of silently reverting to the older dot cursor.
- No gesture ownership, pointer acceleration, click/right-click/double-click, drag-lock, momentum, networking, Mac-host, or remote-control behavior changed.

## Verification status

- Starting head `e0f414507e8ff208dfb54c25ad6958a6420919dd`: Apple Build and Desktop Simulator Smoke green.
- Product commit `9decc6dad9d026c2fe250fe8e653b44960a7c971`: Apple Build and Desktop Simulator Smoke launched on original attempt 1; no rerun/retry/harness masking.
- Desktop Lab: no separate visual run required for the normal production path because explicit production cursor styling is unchanged; this change affects fallback/default rendering consistency only.

## Remaining physical-only checks

NEEDS PHYSICAL TEST: RayNeo negotiated resolution/refresh, overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, deliberate hold-to-move feel, Bluetooth keyboard/mouse, real-service Password AutoFill/passkeys/CAPTCHA/file picker, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

## Next rotation

Focus 4 — windowing/window management, selecting the highest-impact unfinished readiness blocker there after mandatory CI/readiness triage.
