# Focus 7 — Phone Takeover exact web-app refresh

Date: 2026-09-07

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The latest canonical `NATIVE_DESKTOP_GOAL.md` remains the source of truth: one persistent iPhone desktop, no user-facing startup-profile complexity, and no Remote-for-Mac product path. The largest overall software gap remains native productivity depth, particularly richer Sheets range/editing workflows. Physical RayNeo validation also remains outstanding.

## Failure triage

The starting main SHA `01bbac0a63184406b4ed941fb8ea076b12ab8fc5` was green on Apple Build and Apple Integration Smoke, both attempt 1. Gmail failure notifications for `c106219`, `76fd692`, and `ebb260a` were stale relative to current main.

During this run, product SHA `417c42334aaf6cf460de836f8a9e09aa057a7ccc` had its attempt-1 Apple Integration Smoke cancelled when a newer main commit landed. Inspection showed both Apple workflows had branch/ref-wide concurrency with `cancel-in-progress: true`, violating the required per-SHA non-cancelling evidence policy. The harness was hardened before further product work: Apple Build and Apple Integration Smoke now use SHA-scoped concurrency groups with `cancel-in-progress: false`.

## Focus 7 blocker fixed

`PhoneTakeoverView.finalizeTakeoverSession()` previously routed return-from-takeover through `desktop.browserReloadOrStop()`. That helper uses Browser's global loading state to decide whether to stop or reload, even when the authenticated originating app is ChatGPT or YouTube. An unrelated loading Browser tab could therefore cause Return from Phone Takeover to stop the ChatGPT/YouTube desktop WebView instead of refreshing it to observe the new WebKit session cookies.

Product fix: `417c42334aaf6cf460de836f8a9e09aa057a7ccc` (`fix: refresh exact web app after phone takeover`). Phone Takeover now refreshes the exact originating Browser/ChatGPT/YouTube registry key via `DesktopWebInputRegistry.shared.reload(key:)`, while continuing to leave credentials, cookies, passkeys, CAPTCHA and callback URLs under WebKit/iOS ownership.

CI harness fixes:

- `2836ae445f940b47cb2fa6b037ce284798858c18` — `ci: preserve per-SHA Apple build evidence`
- `f4623a5e0c2b67f93cd3a17ec0387b8a0ea6b8dc` — `ci: preserve per-SHA integration evidence`

## Visual / Desktop Lab evidence

No standalone Desktop Lab screenshot comparison is required for this patch because it changes authentication-return routing and CI evidence ownership only. Desktop geometry, external canvas, trackpad layout, cursor rendering, and Phone Takeover visual chrome are unchanged. The Apple Integration Smoke remains the strongest software verification for this batch.

## Remaining physical-only checks

**NEEDS PHYSICAL TEST:** actual RayNeo Air 4 Pro negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer and deliberate window-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback and session handoff, and sustained battery/thermal behavior.

## Next rotation

Focus 8 — native apps, prioritizing the highest-impact unfinished Documents/Sheets readiness blocker rather than novelty features.
