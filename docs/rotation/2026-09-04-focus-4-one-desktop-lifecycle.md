# 2026-09-04 — Focus 4: One-desktop window lifecycle

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

Canonical goal: one persistent desktop. The highest-impact Focus 4 blocker was that the active external-display scene still consulted the legacy `DesktopLaunchProfile.selected` value on the first connection of each app process. A stale Clean/Resume/Work/Browse/Media/Vibe identifier could therefore still shape the normal desktop even though those profiles are retired from the user-facing product.

## Change

Feature head: `f33d20fb36bc96373800e25da8222bada8e68ec1` — `fix: restore one desktop without legacy profiles`.

- The active `ExternalDisplaySceneDelegate` now restores the single persisted desktop directly through `DesktopFeatureState.restoreSession` on the first external-display connection of the process.
- Legacy launch-profile identifiers remain available only for compatibility and are no longer consulted by the normal external-display lifecycle.
- If no persisted desktop exists, the session is explicitly cleared so the user sees the required empty black desktop.
- USB-C reconnect within the same app process preserves the current in-memory windows and does not replay restoration or seed any profile.
- Remote-for-Mac product paths were not touched or exposed.

## Verification state

Pre-change head `a882445e33dacbbd70067d9b5b59aa5f782169aa` was green for Apple Build and Desktop Simulator Smoke, with smoke passing on attempt 1. The newest Gmail failure emails for KamihiRemote remain stale at `2ef9c60` from 2026-09-03.

Exact feature SHA `f33d20fb36bc96373800e25da8222bada8e68ec1` started Apple Build and Desktop Simulator Smoke on attempt 1. At note creation both jobs were queued; no rerun or harness workaround had occurred.

Desktop Lab/visual evidence is pending the same first-attempt simulator smoke artifact. This change is lifecycle/state behavior rather than a new visual design surface.

## Top remaining software blocker

The legacy multi-workspace service and related workspace controls still exist in compatibility code and parts of the roadmap. They must stop surfacing in the normal one-desktop UX, while preserving only migrations/data needed not to break existing users. The next rotation is Focus 5 — phone controller ergonomics — where any remaining user-facing workspace/profile controls should be removed from the normal controller surfaces.

## NEEDS PHYSICAL TEST

- actual negotiated RayNeo Air 4 Pro resolution and refresh rate
- glasses overscan/readability and black levels
- USB-C unplug/reconnect with one-desktop state continuity
- end-to-end pointer and deliberate hold-to-drag latency/feel
- Bluetooth keyboard/mouse
- Password AutoFill/passkeys/CAPTCHA/file picker on real services
- YouTube/ChatGPT login and playback
- long-session battery/thermal/memory behavior
