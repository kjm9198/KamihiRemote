# 2026-09-04 — Focus 6: Browser migration

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

The canonical one-desktop goal makes browser migration a core daily-use requirement. Kamihi already persisted its own bookmarks but offered no supported path to bring user-controlled Safari/Chrome bookmark exports into the desktop browser. That forced a user to recreate bookmarks manually even though public iOS document selection can safely import an exported bookmark file without touching credentials or another browser's private container.

## Change

- Added user-triggered Safari/Chrome/Netscape bookmark HTML import from the Browser library.
- Uses the public SwiftUI file importer and security-scoped URL access only for the file the user selects.
- Imports only `http`/`https` bookmark links.
- Applies Kamihi's existing persisted-URL privacy filter, removing fragments and common auth/token/password query values before saving.
- Deduplicates URLs already present in Kamihi bookmarks.
- Shows a concise import count or import error in the Browser library.
- Explicitly states that passwords, cookies, tokens and another browser's private storage are never imported.
- Does not expose or restore Remote-for-Mac paths.

## Verification state

Pre-change `main` was `6c52cfa99201a01ee51418cb23c5d10d1c3973b5`; Apple Build and Desktop Simulator Smoke were both green. Gmail's newest relevant KamihiRemote failure remained stale at `2ef9c60`.

This change is intentionally one coherent Focus 6 batch. Exact-SHA Apple Build and Desktop Simulator Smoke must pass on attempt 1 before the batch is treated as safe.

## Next rotation

Focus 7 — Phone Takeover/authentication. Select the highest-impact unfinished authentication/readiness blocker without attempting to extract or persist raw credentials.

## NEEDS PHYSICAL TEST

- actual negotiated RayNeo Air 4 Pro resolution/refresh
- glasses overscan/readability and black levels
- USB-C unplug/reconnect continuity
- end-to-end pointer/hold-drag latency and feel
- Bluetooth keyboard/mouse
- Password AutoFill/passkeys/CAPTCHA/file picker on real services
- real Safari/Chrome bookmark-export selection from Files providers
- YouTube/ChatGPT login and playback
- long-session battery/thermal/memory behavior
