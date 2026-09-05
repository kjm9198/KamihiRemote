# Focus 6 — Browser / web-app quality

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment with an iPadOS-quality controller?

Verdict: **NOT READY**. Current software has retained browser tabs, address/search, back/forward/reload, bookmarks/history, user-selected bookmark import, find/share, downloads into Kamihi Files, and conservative WebView retention. The largest browser blocker found in this run was external/app-link handoff from a noninteractive external WebView.

## Failure triage

- Gmail: no failure matched current main; newest KamihiRemote failures are stale September 3 failures on `2ef9c60` / older heads.
- Pre-change main `08df4c3a0995d5b1425255e8135d2c8738a3da53`: Apple Build and Desktop Simulator Smoke green.
- Product change `1b97e52d41c4c404633f6f0d702c822791e4d9a7`: first-attempt CI started after push; no rerun/harness masking.

## Change

`1b97e52d41c4c404633f6f0d702c822791e4d9a7` — `fix: hand browser external links to iPhone`

The Browser navigation delegate now keeps normal `http`/`https` popup navigations in retained Kamihi tabs, but hands external schemes such as `mailto:`, `tel:`, App Store/Maps/app deep links, and supported OAuth callbacks to public `UIApplication.open` on the iPhone. WebKit-owned `about:`, `blob:`, `data:` and `javascript:` URLs remain inside WebKit. This prevents external-link clicks from becoming dead/blank navigations on the noninteractive external display and does not inspect, persist, or log credential payloads.

## Desktop Lab / visual evidence

No rendered layout, pointer geometry, or gesture ownership changed in this batch, so a separate Desktop Lab visual-diff signoff is not required. The integration smoke remains the relevant software gate.

## Next rotation

Focus 7 — Phone Takeover/authentication. Prioritize public-iOS/WebKit login, file-picker, CAPTCHA, passkey/AutoFill handoff reliability over novelty.

## Physical-only checks

Still **NEEDS PHYSICAL TEST**: RayNeo negotiated resolution/refresh, glasses overscan/readability, USB-C replug, end-to-end pointer feel, Bluetooth keyboard/mouse, real-service Password AutoFill/passkeys/CAPTCHA/file picker, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
