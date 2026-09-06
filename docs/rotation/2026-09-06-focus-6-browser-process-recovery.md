# Focus 6 — Browser/web-app quality readiness pass

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. Browser daily-use capability is substantially implemented, but overall desktop readiness is still held back most by native daily-productivity completeness, especially the Sheets import/export workflow and richer spreadsheet editing.

The canonical `NATIVE_DESKTOP_GOAL.md` remains authoritative: Kamihi is one persistent desktop. Do not restore the legacy startup-profile chooser or Remote-for-Mac product path.

## Focus 6 finding

The retained Browser did not implement `webViewWebContentProcessDidTerminate`. iOS may reclaim a WebKit content process during a long external-display session; when that happens, the active tab can be left as a blank/unusable surface even though its tab URL and WebKit website/session data remain available.

Inactive retained tabs should not be revived in the background merely because their renderer was reclaimed, because that would fight the existing Low Power Mode, thermal, background, and memory-pressure policies.

## Change

Product commit `c7b529bc4ec680e4135094a53a2cbbc8abec11c6` (`fix: recover active browser after WebKit termination`) adds Browser-specific WebKit process recovery.

- If the content process for the currently presented Browser WebView is terminated, Kamihi asks WebKit to reload it.
- Inactive retained tabs are deliberately not reloaded; they remain asleep and are recreated lazily when selected.
- No polling timer, display link, credential persistence, cookie copying, or Remote-for-Mac path was added.

This improves long-session Browser/YouTube/ChatGPT-class reliability while preserving the existing conservative WebView lifecycle model.

## Verification

- Baseline head `fceee17fae0b5f540830816bfc8eda030fe15423`: Apple Build + Desktop Simulator Smoke green.
- Gmail failure triage: newest matching KamihiRemote failure emails are stale September 3 failures for old SHA `2ef9c60`; none match the baseline/current product SHA.
- Product head `c7b529bc4ec680e4135094a53a2cbbc8abec11c6`: Apple Build passed. Apple Integration Smoke is running on original attempt 1; trackpad-first controller contract passed and the full simulator-smoke step is in progress at the time this note was recorded.
- No retry or harness workaround has been used.
- Separate Desktop Lab screenshot comparison is not required for this lifecycle-only patch because rendered layout, pointer geometry, gestures, and visible shell UI are unchanged.

## Next rotation

Focus 7 — Phone Takeover/authentication. Choose the highest-impact unfinished readiness blocker in that area; do not add novelty ahead of core authentication and touch-only flow reliability.

## Physical-only checks

Still **NEEDS PHYSICAL TEST** on real iPhone + RayNeo Air 4 Pro/external monitor: negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
