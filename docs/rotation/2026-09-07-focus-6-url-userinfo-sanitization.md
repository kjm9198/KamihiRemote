# Focus 6 — Browser URL user-info sanitization

Date: 2026-09-07

## Readiness audit

Verdict: **NOT READY**.

The canonical one-desktop goal remains authoritative: Kamihi Desktop is an iPhone-powered desktop for external displays, Remote-for-Mac remains retired, and user-facing startup profiles/workspace selection must not be reintroduced. The largest overall software blocker remains everyday native productivity depth, especially richer Sheets range workflows. Inside Focus 6, the highest-impact browser/auth gap found in this run was raw HTTP URL user-info reaching retained browser metadata.

## Failure triage

Starting main: `473f132ced9e79d61d28e5c233e6732fa19cfcfa`.

- Apple Build: success, attempt 1.
- Apple Integration Smoke / desktop-simulator-smoke: success, attempt 1.
- Newest Gmail failure messages were stale PR failures for older SHA `c106219`; no failure matched starting main.

## Change

Product commit: `991ea07d16ca7a6a0d4e1d561879db7258a7ff06` — `fix: strip URL credentials before browser navigation`.

`DesktopBrowserNavigationDelegate` now detects HTTP/HTTPS URLs containing RFC URL user-info such as `https://user:password@example.com/...`, strips the user/password components before allowing or recreating the navigation, and routes the sanitized URL instead. This prevents raw URL credentials from entering retained tab/history metadata while preserving ordinary WebKit/iOS authentication mechanisms. Existing query/fragment persistence sanitization remains unchanged.

No Mac-host pairing/networking/remote-control product path was touched.

## Verification

For product SHA `991ea07d...`, Apple Build and Apple Integration Smoke registered on original attempt 1. At the time this note was recorded, both were still running; Integration had already passed setup, checkout, Xcode verification and the trackpad-first controller contract and was executing the full simulator smoke. No rerun/retry/harness workaround was used.

Desktop Lab screenshots were not required because this change has no UI, geometry, pointer, or controller visual change. The strongest relevant checks are simulator build and integration smoke.

## Remaining blocker / next focus

Top overall software blocker: true Sheets range/multi-cell selection and copy, practical row/column operations, stronger editing and lightweight formulas.

Next rotation: Focus 7 — Phone Takeover/authentication, after exact-head CI triage.

## Physical-only checks

Still **NEEDS PHYSICAL TEST**: actual RayNeo Air 4 Pro negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer and deliberate hold-to-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and sustained battery/thermal behavior.
