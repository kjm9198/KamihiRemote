# Focus 4 — Windowing / window management readiness

## Readiness verdict

NOT READY.

The current canonical goal is one persistent iPhone-powered desktop. Remote-for-Mac and startup-profile/workspace chooser product paths remain retired; compatibility identifiers may remain only where required for existing data/build compatibility.

## Failure triage

- Starting main: `46a3daf6baade29842ce00a2713e1b2109c68176`.
- Gmail: newest matching KamihiRemote failures are stale `ebb260a` Apple Build / Apple Integration Smoke notifications; no current-head failure matched.
- Exact starting-head GitHub checks: Apple Build and Desktop Simulator Smoke both completed successfully.

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Answer: no. Window manipulation is substantially implemented, but reliable close/maximize/minimize targeting and intelligent first placement remain important readiness work. The roadmap is stale where it still describes direct all-edge resizing as TODO; current `DesktopWindowView` exposes eight resize affordances and `DesktopSession` implements all-edge/corner resize ownership through the iPhone pointer.

The largest windowing gap observed in this audit is that the main productivity-app launcher still uses one fixed default rectangle instead of the newer overlap-aware `preferredFloatingFrame` placement path. That should be migrated in a dedicated safe edit rather than rewriting the large legacy compatibility file through a whole-file connector replacement.

## Change in this run

Product commit: `ae95326bb03e367b1b4232887f8306019906e0b6` — `fix: enlarge software window control hit targets`.

`DesktopWindowChrome.action(at:in:)` now gives minimize/maximize/close a larger normalized software-pointer target and uses nearly the full title-bar height while preserving one continuous deterministic control cluster. Inter-button gaps continue resolving to the nearest control and cannot leak into title-bar dragging. The change is geometry-only, timer-free, and resolution-independent.

## Verification

- Product exact-SHA Apple Build: attempt 1 started; status was in progress when this note was recorded.
- Product exact-SHA Desktop Simulator Smoke: attempt 1 started; status was in progress when this note was recorded.
- No same-SHA rerun or retry was used.
- Desktop Lab: no separate screenshot evidence required because rendered chrome appearance and window geometry are unchanged; this changes software-pointer hit geometry only. Simulator integration evidence remains the relevant automated gate.

## Next Focus

Focus 5 — phone controller ergonomics, selecting the highest-impact unfinished readiness blocker after exact-SHA CI is green.

## Physical-only checks

NEEDS PHYSICAL TEST: negotiated RayNeo Air 4 Pro resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer/window-control feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
