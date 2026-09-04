# 2026-09-04 — Focus 7: Phone Takeover/authentication

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

The largest overall software blocker remains stable, fully verified multi-workspace/Spaces behavior across rapid switching and recovery. In this Focus 7 rotation, the highest-impact authentication blocker found was a trust-signaling bug in Phone Takeover: the chrome always displayed a lock/shield and “Secure phone interaction,” even if the loaded page itself used unencrypted HTTP.

## Change

Product commit: `5c9d43a6054066ae70f380d5eb903fc1457be905` — `fix: show truthful takeover transport security`.

- HTTPS pages now show an explicit encrypted-connection state.
- HTTP pages show a warning that the connection is not encrypted and advise against entering passwords or sensitive information.
- Non-web/initial takeover states describe the privacy boundary without falsely claiming transport encryption.
- Accessibility announces the same transport-security state and detail.
- The takeover continues to keep Password AutoFill, passkeys, CAPTCHA, file-picking and page credentials inside iPhone/WebKit; Kamihi still does not read or persist raw credentials.
- Full callback URLs remain hidden from Kamihi chrome, so OAuth codes/tokens in query strings or fragments are not exposed visually.
- Retired Remote-for-Mac product paths were not touched.

## CI / validation

Pre-change head `fd8530d21dea59d393a86a78fc9ba67776ff390f` was green: Apple Build and Apple Integration Smoke both passed on attempt 1. Gmail’s newest KamihiRemote failures remained stale September 3 failures for `2ef9c60` and older SHAs.

For product commit `5c9d43a6054066ae70f380d5eb903fc1457be905`, Apple Build passed on attempt 1. Apple Integration Smoke was still on attempt 1 when this note was created; checkout, Xcode verification, and the trackpad-first controller contract had passed and the simulator smoke was still running. No rerun or retry masking was used.

Desktop Lab visual evidence is pending the same first-attempt smoke artifact because the change alters takeover UI/security messaging.

## Remaining physical-only validation

`NEEDS PHYSICAL TEST`: actual RayNeo negotiated resolution/refresh, overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

## Next rotation

Focus 8 — native desktop apps. Choose the highest-impact unfinished readiness blocker there rather than adding novelty.
