# 2026-09-04 — Focus 8: Native desktop apps

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

The largest overall software blocker remains stable, fully verified independent multi-workspace/Spaces behavior under rapid switching and recovery. Within Focus 8, the clipboard utility had a privacy/coherence mismatch: Kamihi's Clear action removed only its in-memory history while copied text could remain on the iOS system clipboard.

## Change

Feature head: `72a386035c9fa652f72a284f4e0768fb3308403b` — `fix: clear system clipboard with history`.

- Clipboard Center now explains that Kamihi clipboard history is memory-only and is not persisted.
- The destructive Clear action now uses an explicit confirmation dialog.
- Confirming Clear removes both Kamihi's in-memory clipboard history and the current iOS system clipboard contents.
- Clipboard reads remain user-driven: when Clipboard Center opens or when the user presses Refresh. No background clipboard polling or persistence was added.
- VoiceOver receives a concise clipboard privacy description.
- Remote-for-Mac product paths were not changed or exposed.

## Verification state

Pre-change head `47d8facf6f6cb7d832e4cd2d79bd5fa324068d96` was green for Apple Build and Desktop Simulator Smoke. The newest Gmail failure mail for KamihiRemote remains stale at `2ef9c60`.

Exact feature SHA `72a386035c9fa652f72a284f4e0768fb3308403b` started Apple Build and Apple Integration Smoke on attempt 1. At note creation both were still in progress; no rerun or harness workaround had occurred. The trackpad-first controller contract passed before the simulator smoke step began.

Desktop Lab visual evidence is pending the same attempt-1 smoke artifact. This change affects a phone-side native utility surface rather than external desktop window geometry or pointer rendering.

## Next rotation

Focus 9 — performance/energy/WebView lifecycle. Prefer the highest-impact remaining readiness blocker in that area, especially deliberate long-idle inactive WebView release that preserves session/login state and does not introduce idle polling.

## NEEDS PHYSICAL TEST

- actual negotiated RayNeo Air 4 Pro resolution and refresh rate
- glasses overscan/readability
- USB-C unplug/reconnect
- end-to-end pointer latency and feel
- Bluetooth keyboard/mouse
- Password AutoFill/passkeys/CAPTCHA/file picker on real services
- YouTube/ChatGPT login and playback
- Clipboard clear behavior on a real iPhone
- long-session battery/thermal/memory behavior
