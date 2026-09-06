# Focus 5 — Phone controller ergonomics readiness pass

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The phone controller is already predominantly a full-screen trackpad with Keyboard and More as the only permanent controls, but the overall product is still held back most by daily productivity depth, especially richer Sheets workflows.

The canonical `NATIVE_DESKTOP_GOAL.md` remains authoritative: Kamihi is one persistent desktop. Remote-for-Mac and the old startup-profile chooser stay retired.

## Focus 5 finding

The controller can intentionally exit back to the lightweight entry state, but the compatibility `AppMode.none` metadata still called that state **Startup Profiles**, described it as choosing how Kamihi should start, and used a profile-grid symbol. That stale metadata could leak retired product language through any surface that reads `AppMode` labels even though the actual entry view has already been simplified to one **Enter Desktop** action.

## Change

Product commit `aae6675f447d9a1e37b59ac52a7a9b471e6f3245` (`fix: remove retired startup profile labels`) keeps `.none` only as the internal entry-state identifier while presenting it as **Kamihi Desktop** with one persistent-desktop wording and a display symbol. The launch-argument comment now also describes the normal destination as the simple one-desktop entry screen.

This preserves compatibility identifiers without re-exposing startup profiles or Mac-remote product paths.

## Verification

- Baseline head `a24ae2a63705477dcba657c70eceea53560325bd`: Apple Build + Desktop Simulator Smoke green.
- Product head `aae6675f447d9a1e37b59ac52a7a9b471e6f3245`: Apple Build and Desktop Simulator Smoke started on attempt 1. At note time, the trackpad-first controller contract had passed and the full Kamihi Desktop simulator smoke was running. No rerun or harness workaround had occurred.
- Separate Desktop Lab screenshot comparison is not required for this metadata-only text/symbol cleanup; desktop geometry, controller layout, pointer behavior, and gesture routing are unchanged.

## Next rotation

Focus 6 — Browser/web-app quality and migration. Choose the highest-impact unfinished readiness blocker in that area before adding novelty.

## Physical-only checks

Still **NEEDS PHYSICAL TEST** on real iPhone + RayNeo Air 4 Pro/external monitor: negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, deliberate window-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
