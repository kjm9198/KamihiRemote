# 2026-09-06 — Focus 7: Phone Takeover/authentication

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

The canonical product remains one persistent iPhone desktop with Remote-for-Mac retired and no user-facing startup-profile chooser. The largest overall software blocker remains everyday productivity depth, especially richer Sheets workflows. Inside Focus 7, the highest-impact unfinished reliability blocker found was Phone Takeover navigation failure recovery: non-cancelled WebKit navigation failures only stopped the loading state and could leave a login/touch-only flow at a dead end with no clear recovery action.

## Change

Product commit: `9e7868ea1422b7e812ce63b542924f66ad33e1fc` — `fix: surface takeover navigation failures safely`.

- Phone Takeover now surfaces a clear `Sign-In Page Couldn't Load` recovery alert for genuine WebKit navigation failures.
- The user can retry using the existing live `WKWebView` without leaving the takeover flow.
- Normal `NSURLErrorCancelled` events are ignored so redirects, cancellations and custom-scheme handoffs do not produce false error UI.
- Error details from providers/WebKit are not copied into Kamihi UI or state; callback URLs, OAuth codes, tokens and provider-specific request details remain out of Kamihi-owned error strings.
- Passwords, passkeys, CAPTCHA, file pickers, cookies and session state remain owned by iOS/WebKit via the default persistent website data store.
- Remote-for-Mac paths were not touched.

## CI / validation

Pre-change head `a09c5228bed90692c2c9b32600fad324c939a180` was green on Apple Build and Apple Integration Smoke, both attempt 1. Gmail's newest KamihiRemote failures remained stale `ebb260a` notifications.

For product commit `9e7868ea1422b7e812ce63b542924f66ad33e1fc`, Apple Build passed on attempt 1. Apple Integration Smoke remained on its original attempt 1 while this note was recorded: setup, checkout, Xcode verification and the trackpad-first controller contract had passed, and the full Kamihi Desktop simulator smoke was still running. No same-SHA rerun, retry or harness workaround was used.

Desktop Lab screenshot comparison is not separately diagnostic for this error-path-only change; normal desktop/controller geometry is unchanged. The exact-SHA simulator smoke/evidence remains the automated gate.

## Remaining blockers

Top overall software blocker: richer Sheets productivity workflows (range/multi-cell selection, range copy/paste, row/column operations and lightweight formulas).

## Remaining physical-only validation

`NEEDS PHYSICAL TEST`: actual RayNeo negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer and deliberate window-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

## Next rotation

Focus 8 — native desktop apps. Choose the highest-impact unfinished readiness blocker there rather than adding novelty.
