# Focus 2 — Dock Increase Contrast fidelity

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: NOT READY. The canonical product remains one persistent iPhone desktop with Remote-for-Mac and user-facing startup profiles retired. The largest overall software-readiness blocker remains richer everyday productivity behavior, especially Sheets range selection/copy, row/column operations, and lightweight formulas.

## Failure triage

Gmail's newest KamihiRemote failures are stale SHA `76fd692`. Starting main `5736a243ddb4f405969109a12421a66acf56a512` had Apple Build and Apple Integration Smoke green on original attempt 1.

## Focus 2 finding

The shared shell chrome already reacted to Increase Contrast, but the always-visible dock's inner App Library button, app tiles, running indicators, status capsule, and decorative shadow only reacted to Reduce Transparency. This left the most persistent desktop shell surface less distinct than the rest of the semantic design system when iOS Increase Contrast was enabled.

## Change

Product commit: `781e5936eab498458db738addc9751bcd11505fa` — `fix: honor increased contrast across desktop dock`.

- Dock now observes `colorSchemeContrast` directly.
- Increase Contrast switches inner dock/status surfaces to opaque semantic canvases, matching Reduce Transparency behavior.
- Launcher and app tiles gain stronger semantic separator borders in increased-contrast mode.
- Active app accent borders become more distinct and running indicators become slightly thicker without relying on color alone.
- Decorative dock shadow is removed when either Reduce Transparency or Increase Contrast requires solid chrome.
- System/Light/Dark semantic colors, SF Symbols, 44-point targets, and the plain black desktop remain unchanged.
- No Mac-host, pairing, networking, remote-control, startup-profile, or proprietary-trade-dress path was added.

## Verification

At note creation, Apple Build and Apple Integration Smoke for the product SHA are running on original attempt 1. Integration setup, checkout, Xcode selection, and the trackpad-first controller contract have passed; the full simulator smoke is still running. No retry, rerun, or harness workaround has been used.

Desktop Lab: this is an accessibility-setting-specific shell visual change. The normal simulator smoke/evidence path is running; physical contrast/readability through RayNeo remains a physical validation item.

## Remaining physical-only checks

NEEDS PHYSICAL TEST: actual RayNeo Air 4 Pro negotiated resolution/refresh, overscan/readability including Increase Contrast appearance in glasses, USB-C unplug/reconnect, end-to-end pointer/window feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.

## Next rotation

Focus 3 — trackpad/pointer, selecting the highest-impact unfinished readiness blocker after exact-head failure triage.