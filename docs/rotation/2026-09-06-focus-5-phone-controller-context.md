# Focus 5 — Phone controller ergonomics readiness pass

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The controller itself is strongly trackpad-first, but overall desktop readiness is still held back most by native daily-productivity completeness, especially the Sheets import/export workflow and richer spreadsheet editing.

The canonical `NATIVE_DESKTOP_GOAL.md` remains authoritative: Kamihi is one persistent desktop. Do not restore the legacy startup-profile chooser or Remote-for-Mac product path.

## Focus 5 finding

The controller's More menu exposed **Continue on iPhone** for every active window. Phone Takeover intentionally supports only Browser, ChatGPT, and YouTube because those surfaces can need Password AutoFill, passkeys, CAPTCHA, file pickers, or other touch-only WebKit flows. Native Kamihi apps therefore opened a dead-end “No Phone Takeover Needed” sheet.

## Change

Product commit `82478fcbda9976848d3f4eef7da678ddd1b9d4b8` (`fix: hide unavailable phone takeover actions`) limits the contextual **Continue on iPhone** action to Browser, ChatGPT, and YouTube. Native apps no longer show an irrelevant controller action.

This preserves the phone as a predominantly full-screen trackpad with only Keyboard and More permanently visible while making the More menu more contextual and one-handed.

## Verification

- Baseline head `89d325d873eb23f7046caccd3265cbb1df66da4e`: Apple Build + Apple Integration Smoke green, attempt 1.
- Product head `82478fcbda9976848d3f4eef7da678ddd1b9d4b8`: Apple Build passed; Apple Integration Smoke passed on attempt 1, including trackpad-first controller contract, Kamihi Desktop simulator smoke, and evidence upload.
- No retry or harness workaround was used.
- Separate Desktop Lab screenshot comparison was not necessary for this small contextual-menu visibility correction; trackpad geometry, pointer behavior, gestures, and desktop rendering were unchanged.

## Next rotation

Focus 6 — Browser/web-app quality and migration. Choose the highest-impact unfinished readiness blocker in that area; do not add novelty ahead of core daily-use reliability.

## Physical-only checks

Still **NEEDS PHYSICAL TEST** on real iPhone + RayNeo Air 4 Pro/external monitor: negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
