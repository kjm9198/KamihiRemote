# 2026-09-04 — Focus 1: external-display / RayNeo fidelity

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. Current software is coherent enough for continued validation, but stable independent workspaces, web-app pinning, adaptive/readable glasses scaling, and several physical RayNeo checks still block a READY verdict.

## Failure triage

- Gmail's newest KamihiRemote failure notices are stale older-SHA failures (`2ef9c60` and earlier).
- Pre-change `main` was `f7908f32187965b2914a9c100ede03888e7ae6a6`.
- Apple Build and Desktop Simulator Smoke were both green for that exact SHA; smoke completed successfully on attempt 1.

## Focus 1 change

This run hardens external-scene geometry after display negotiation:

- The external `UIWindow` now follows `UIWindowScene.coordinateSpace.bounds` rather than assuming `UIScreen.bounds` is always the final logical scene rectangle.
- The backing scale continues to come only from the iOS-negotiated `UIScreen.nativeScale`; Kamihi still does not force display modes or 120 Hz.
- `sceneDidBecomeActive` now reapplies negotiated geometry and refreshes display metrics. This covers adapters/displays whose final mode settles after initial scene connection without creating polling or an idle timer.
- `windowScene(_:didUpdate:interfaceOrientation:traitCollection:)` reuses the same geometry path, keeping reconnect/mode/overscan changes consistent.
- No Remote-for-Mac product path was exposed or extended.

## Verification state

The change is intentionally isolated to external-display scene geometry and adds no new UI surface. Desktop Lab screenshot review is therefore not required for the code change itself; exact-SHA Apple Build and Desktop Simulator Smoke remain mandatory after push.

## Top remaining software blocker

The largest software-readiness blocker remains **true independent persistent multi-workspace/Spaces behavior**. Within external-display fidelity specifically, automatic readable/adaptive glasses scaling remains unfinished after geometry fidelity.

## NEEDS PHYSICAL TEST

- Actual iPhone + RayNeo Air 4 Pro negotiated resolution and refresh.
- Overscan and text readability through the glasses.
- USB-C unplug/reconnect continuity and delayed mode settling.
- End-to-end pointer/scroll/gesture latency and feel.
- Bluetooth keyboard/mouse behavior.
- Password AutoFill, passkeys, CAPTCHA and file picker on real services.
- YouTube/ChatGPT login and playback.
- Long-session battery, thermal, memory and WebKit behavior.

## Next rotation

Proceed to **Focus 2 — iPadOS-style shell/design system**, choosing the highest-impact unfinished readiness blocker rather than novelty work.
