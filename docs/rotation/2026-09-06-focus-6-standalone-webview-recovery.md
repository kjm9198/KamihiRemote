# Focus 6 — Browser / Web-App Quality

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: NOT READY.

The canonical NATIVE_DESKTOP_GOAL remains one persistent iPhone desktop with Remote-for-Mac retired. The largest overall software-readiness blocker remains everyday productivity depth, especially richer Sheets range editing/copy-paste/formula workflows. Inside Focus 6, the highest-impact unfinished reliability gap was standalone web-app recovery after WebKit renderer reclamation.

## Change

Product commit: `bbaebf517143dc0553cbb219008d95243c3d3f17` (`fix: recover standalone web apps after WebKit termination`).

`WKWebViewRepresentable` now gives standalone ChatGPT, YouTube and Phone Takeover surfaces a `WKNavigationDelegate`. If iOS terminates the active WebKit content process during a long external-display session, the still-presented WebView reloads. Hidden/dismantled views do not restart work. The shared default `WKWebsiteDataStore` continues to own login/session state; Kamihi does not read or persist raw credentials.

Dismantling also clears the navigation delegate so closed/replaced views cannot continue receiving recovery callbacks.

## Verification

- Starting head `dd1b10be8133bfd3ae972d7016c7671b0b27e96d`: Apple Build and Desktop Simulator Smoke green.
- Gmail failure triage: newest KamihiRemote failure mail is stale `ebb260a`; none matched current head.
- Product SHA CI was started on original attempt 1; Apple Build and Desktop Simulator Smoke were in progress when this note was recorded. No rerun/retry/harness workaround was used.
- Desktop Lab: no separate screenshot comparison required because rendered layout/input geometry is unchanged; this is WebKit lifecycle recovery behavior.

## Next rotation

Focus 7 — Phone Takeover/authentication. Continue choosing the highest-impact unfinished readiness blocker in that area and do not restore startup profiles or Remote-for-Mac paths.

## Physical-only validation

Still NEEDS PHYSICAL TEST: negotiated RayNeo resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer/hold-to-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and sustained battery/thermal behavior.
