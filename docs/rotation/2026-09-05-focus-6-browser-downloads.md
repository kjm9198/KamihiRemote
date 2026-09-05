# Focus 6 — Browser/web-app quality: downloads into Files

## Readiness audit

Question: if the iPhone is connected to RayNeo Air 4 Pro or a normal external display right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop with an iPadOS-quality controller?

Verdict: **NOT READY**. The canonical `NATIVE_DESKTOP_GOAL.md` still identifies native Sheets as the largest overall software-readiness blocker. Within Focus 6, the highest-impact browser gap was that WebKit downloads completed into a browser-only Application Support directory that the user could not manage from Kamihi's native Files app.

## Failure triage

- Gmail: no failure for current `main`; newest KamihiRemote failures remain stale September 3 failures for `2ef9c60` and older SHAs.
- Pre-change `main`: `3dbc56a928289b2a502d6abf14e2af8429235044`.
- Pre-change exact checks: Apple Build and Desktop Simulator Smoke both green.
- No Remote-for-Mac product work performed.

## Change

Source commit: `9bebb325a5eb397c58e62f17d8e6a4f135522841` — `fix: surface browser downloads in Files`.

- Browser downloads now target the same Kamihi-owned `Kamihi Desktop Files` Application Support directory used by the native Files app.
- Completed downloads therefore become available through Files for native PDFKit/Quick Look preview, Share/Export, and deletion on next Files refresh/open.
- Existing downloads from the older `Kamihi Desktop/Browser Downloads` silo are migrated collision-safely into the unified Files library when the browser next resolves a download destination.
- Suggested filenames remain sanitized and duplicate names remain collision-safe.
- `WKDownload` resume data is still not persisted because it can contain request/session material.
- No passwords, cookies, tokens, response bodies, or raw credentials are read or logged.

## Verification

- Source SHA exact Apple Build: attempt 1 started.
- Source SHA exact Desktop Simulator Smoke: attempt 1 started; checkout, Xcode version, and trackpad-first controller contract passed before the core simulator smoke step.
- No retry/rerun/harness masking was used.
- Desktop Lab screenshot comparison is not required for this storage-routing change because it does not alter rendered UI/input geometry. The simulator integration smoke is the relevant software integration evidence.

## Remaining blocker / next rotation

Top overall software blocker remains **native Sheets**. Next rotation is Focus 7 — Phone Takeover/authentication, choosing the highest-impact unfinished readiness blocker in that area after exact-head CI is green.

## Physical-only checks

Remain **NEEDS PHYSICAL TEST**: actual RayNeo negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency/feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
