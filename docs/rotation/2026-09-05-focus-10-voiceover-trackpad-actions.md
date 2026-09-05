# 2026-09-05 — Focus 10: VoiceOver trackpad actions

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. Current software CI was green before this run, but the canonical one-desktop goal still has core readiness gaps. The largest overall product blocker remains the missing native Sheets app. Inside Focus 10, the highest-impact accessibility gap was that VoiceOver users could focus the full-screen trackpad but its documented touch gestures are intercepted by VoiceOver and there were no equivalent rotor/custom actions for essential desktop controls.

## Failure triage

- Gmail's newest KamihiRemote GitHub failure notices are stale older-SHA failures, newest `2ef9c60` from 2026-09-03.
- Pre-change `main` was `e3f9e5744c8294ddde3da926249cb1423c2224c6`.
- Its Apple Build and Desktop Simulator Smoke were both green on attempt 1.

## Focus 10 change

Product commit: `771eba7050477bb3e6c91b82ffbb0faaae338ff7` — `feat: add VoiceOver desktop trackpad actions`.

- Added VoiceOver custom actions to the normal full-screen desktop trackpad for:
  - Click at Pointer.
  - Right Click at Pointer.
  - Next Window.
  - Previous Window.
  - Window Overview.
  - Keyboard / Hide Keyboard.
- The trackpad now exposes the active-window title as its accessibility value.
- The accessibility hint no longer tells VoiceOver users to rely on multi-finger trackpad gestures that VoiceOver can consume; it points them to the custom actions instead.
- Window switching clears any outstanding phone-keyboard request before focus changes so typed text cannot leak to the newly focused window.
- Normal touch behavior remains unchanged when VoiceOver is off.
- No Remote-for-Mac product path was exposed or extended.

## Verification status

At the time of this note, exact product SHA `771eba7050477bb3e6c91b82ffbb0faaae338ff7` has Apple Build and Desktop Simulator Smoke queued on original attempt 1. No retry or harness workaround has occurred.

Desktop Lab visual review is not required for this batch because it adds accessibility semantics/actions without changing rendered layout. The simulator smoke remains the relevant integration evidence.

## Remaining blockers

Top overall software blocker: native **Sheets** for lightweight spreadsheet/table work, Files integration, persistence and import/export.

Focus-10 follow-ups include broader VoiceOver focus-navigation validation, real Bluetooth keyboard testing, large-content accessibility checks, and verifying the new rotor/custom actions on a physical iPhone.

## NEEDS PHYSICAL TEST

- Actual iPhone + RayNeo Air 4 Pro negotiated resolution and refresh.
- Overscan/readability in glasses.
- USB-C unplug/reconnect continuity.
- End-to-end pointer and deliberate hold-to-move feel.
- Bluetooth keyboard/mouse behavior.
- VoiceOver rotor/custom-action behavior on a real iPhone.
- Password AutoFill, passkeys, CAPTCHA and file picker on real services.
- YouTube/ChatGPT login and playback.
- Long-session battery/thermal behavior.

## Next rotation

Return to **Focus 1 — external-display/RayNeo fidelity**, selecting the highest-impact unfinished readiness blocker in that area. Do not restore startup-profile/workspace complexity from the older roadmap.