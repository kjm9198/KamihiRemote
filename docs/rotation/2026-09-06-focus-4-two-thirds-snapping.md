# Focus 4 — Windowing / Two-Thirds Snapping Readiness

## Readiness audit

Current product direction follows `NATIVE_DESKTOP_GOAL.md`: one persistent iPhone desktop, no user-facing startup-profile chooser, and no Remote-for-Mac product path.

Starting head `dae39b3f75c337fa0c1ad44abbd3735d470a1dab` was green on Apple Build and Apple Integration Smoke, both original attempt 1. Gmail's newest KamihiRemote failure notifications were stale failures for older SHA `76fd692`.

The highest-impact unfinished blocker inside Focus 4 was a real gap between the roadmap and the snap engine: halves, quarters, and single-thirds were available, but the roadmap's required 2/3 layouts did not exist as snap targets at all.

The overall highest software-readiness blocker remains richer everyday productivity depth, especially Sheets range/multi-cell selection/copy, row/column operations, stronger editing, and lightweight formulas.

## Change

Product commit: `45a59cb1f8ac2c49fd58252330ab177fd4c8f5d9` — `feat: add two-thirds desktop snapping`.

- Added `Left Two Thirds` and `Right Two Thirds` snap targets.
- Added bounded normalized 2/3 geometry aligned to the existing third grid and desktop safe margins.
- Expanded the deliberate title-bar top-edge snap zones into five spatial regions: left 1/3, left 2/3, center 1/3, right 2/3, right 1/3.
- Kept the narrow top-center maximize throw target.
- Existing live snap preview remains the feedback mechanism and release remains the commit point; moving away cancels the preview.
- No permanent chrome, workspace/profile complexity, Mac-host networking, pairing, or remote-control behavior was added.

## Verification status

- `DesktopRefactorTests` already iterates every `WindowSnapEngine.SnapTarget`, so the new two-thirds targets automatically participate in normalized geometry bounds self-checks.
- Product SHA Apple Build and Apple Integration Smoke launched on original attempt 1; no rerun/retry/harness masking was used.
- At documentation time, exact-SHA CI was still running.
- Desktop Lab: this changes snap target geometry and drag-preview selection rather than shell layout at rest. The CI simulator evidence path remains required; final RayNeo drag feel remains physical-only.

## Remaining software blocker

The next major overall blocker remains Sheets productivity depth. The next rotation area is Focus 5 — phone controller ergonomics, selecting the highest-impact unfinished readiness issue there after mandatory CI/readiness triage.

## Physical-only checks

NEEDS PHYSICAL TEST: RayNeo Air 4 Pro negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency and deliberate window-move/snap feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
