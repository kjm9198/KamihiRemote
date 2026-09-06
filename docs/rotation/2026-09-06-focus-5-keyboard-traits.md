# Focus 5 — Phone controller ergonomics

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The largest overall software blocker remains everyday native productivity depth, especially richer Sheets range selection/copy, row/column operations, editing, and lightweight formulas. Within Focus 5, the highest-impact controller ergonomics gap was that the phone keyboard proxy forced `autocapitalization(.never)` and disabled autocorrection for every desktop app, including writing-heavy apps.

## Change

Product commit `281bb07d24b29dd18b557c992264a53a1594e253` makes the trackpad-first phone keyboard adapt its typing traits to the active desktop app without adding permanent controller chrome:

- Browser and Sheets keep autocorrection disabled and capitalization off, avoiding unwanted URL/cell-value rewrites.
- Notes, Documents, ChatGPT, YouTube, and other text-heavy contexts use sentence capitalization and normal iOS autocorrection/prediction.
- The keyboard proxy keeps its captured-window ownership rule, so focus changes still close the keyboard instead of redirecting text into another window.
- App-aware placeholders clarify the current typing target while retaining the same compact keyboard bar geometry.
- The existing diff-based text forwarding remains compatible with predictive/autocorrect replacements because replacements are routed as deterministic backspace + insertion deltas.

No Mac-host pairing/networking/remote-control work was restored. No startup-profile UI was added; the canonical one-desktop goal remains authoritative.

## Verification

- Starting main `91d62d444a5d19754a9ca626e0e952716d47e504`: Apple Build and Desktop Simulator Smoke green.
- Gmail failures matched at run start: stale `76fd692` Apple Build / Apple Integration Smoke failures; none for starting current head.
- Product SHA `281bb07d24b29dd18b557c992264a53a1594e253`: Apple Build passed on attempt 1; Desktop Simulator Smoke was still running on original attempt 1 when this note was written. No rerun/retry/harness masking.
- Desktop Lab: no separate screenshot comparison required because controller geometry and visible trackpad chrome are unchanged; this is keyboard behavior/typing-trait routing. Simulator evidence remains the relevant software gate.

## Remaining physical-only checks — NEEDS PHYSICAL TEST

Actual RayNeo Air 4 Pro negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer and deliberate window-move feel, Bluetooth keyboard/mouse, real iPhone keyboard prediction/autocorrection feel, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and sustained battery/thermal behavior.

## Next rotation

Focus 6 — browser/web-app quality and migration, after exact-head CI triage. The top overall software blocker remains Sheets productivity depth and should be addressed when Focus 8 rotates back in.