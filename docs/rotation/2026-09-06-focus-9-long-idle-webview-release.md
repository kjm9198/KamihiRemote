# Focus 9 — Long-idle WebView release

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The overall top software blocker remains native productivity depth, especially richer Sheets range/editing behavior. Inside Focus 9, the highest-impact unfinished blocker was the roadmap's explicit lack of a deliberate long-idle WebView release policy.

## CI triage

- Gmail: newest matching failure notifications are stale `ebb260a` Apple Build / Apple Integration Smoke failures.
- Starting head `6cbc510caf6b3c1ee57feed8df3bb2f1cc8f2e74` was green on Apple Build and Apple Integration Smoke.
- Product change SHA: `980dbfb9366c6fd9841f5393ef9a27cb067ecad8`.
- Apple Build passed on attempt 1.
- Apple Integration Smoke ran on attempt 1; trackpad-first controller contract, full simulator smoke, and smoke evidence upload all passed without rerun or harness workaround.

## Change

Inactive web-backed desktop windows (Browser, ChatGPT, YouTube) now retain their live renderer for normal fast app switching, but after 15 minutes continuously inactive they release their content surface. Reactivating the window cancels the pending idle release immediately and recreates content through the app's existing URL/session/WebKit persistence paths.

The implementation deliberately uses one cancelable, self-terminating Swift concurrency sleep per inactive web window. It does not introduce a polling timer, CADisplayLink, or idle render loop. Minimized windows still release immediately; Low Power Mode, manual Battery Saver, and serious/critical thermal pressure still use the existing more aggressive policy.

## Desktop Lab / visual evidence

No separate Desktop Lab screenshot comparison was necessary because this changes renderer lifetime after prolonged inactivity and does not alter desktop geometry, pointer behavior, controller layout, window chrome, typography, or normal web-app rendering. The exact product SHA completed the standard simulator smoke/evidence path on attempt 1.

## Remaining blockers

Top software blocker: Sheets still needs true range selection/copy, stronger replacement editing, practical row/column operations, and lightweight formulas before Kamihi feels dependable for everyday productivity.

Next rotation: Focus 10 — keyboard/accessibility/final polish.

## Physical-only checks

Remain **NEEDS PHYSICAL TEST**: RayNeo Air 4 Pro negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer/window-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and sustained battery/thermal behavior during long sessions.
