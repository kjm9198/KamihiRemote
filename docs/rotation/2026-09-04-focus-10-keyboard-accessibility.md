# 2026-09-04 — Focus 10: keyboard/accessibility/polish

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**. The software baseline is increasingly coherent, but the roadmap still has core readiness gaps including independent persistent desktop workspaces, Browser web-app pinning, automatic adaptive/glasses UI scaling, and long-idle WebView lifecycle policy. RayNeo hardware readiness also remains blocked on physical validation.

## Failure triage

- Gmail's newest KamihiRemote GitHub failure notices were stale older-SHA failures (`2ef9c60` and earlier).
- Pre-change `main` was `8e02349cf64c1ef8abc9f408e1f077ced25748d5`; Apple Build and Apple Integration Smoke were green on attempt 1.

## Focus 10 change

Product commit: `83d242bd4afc00761d9b00767b991b0406d5b4a2` — `feat: add hardware minimize shortcut`.

- Added Command-M for **Minimize Active Window** to the normal Desktop hardware-keyboard shortcut layer.
- The shortcut clears any outstanding phone software-keyboard request before minimizing, so focus cannot move to the next visible window while stale text-input ownership remains behind.
- The command remains visually hidden/discoverable through iPadOS keyboard shortcuts, preserving the full-screen trackpad-first phone controller.
- It deliberately does not use Control-Option, preserving VoiceOver's reserved modifier chord.
- No Remote-for-Mac product path was exposed or extended.

## Verification

Exact product SHA `83d242bd4afc00761d9b00767b991b0406d5b4a2`:

- Apple Build: **PASS**, attempt 1.
- Apple Integration Smoke / Desktop Simulator Smoke: **PASS**, attempt 1.
- Trackpad-first controller contract: **PASS**.
- Smoke evidence artifact uploaded as `kamihi-desktop-smoke-1`.
- Desktop Lab visual inspection was not required for this batch because it changes only hardware-keyboard routing and adds no visible UI/input-rendering surface.

## Remaining blockers

Top software blockers remain:

1. True independent persistent multi-workspace/Spaces behavior.
2. Browser web-app pinning and remaining daily-use browser completeness.
3. Automatic adaptive/glasses UI scaling.
4. Deliberate long-idle inactive WebView release policy without losing session continuity.
5. Broader hardware-keyboard focus/navigation validation on real hardware.

## NEEDS PHYSICAL TEST

- Actual iPhone + RayNeo Air 4 Pro negotiated resolution and refresh.
- Overscan and text readability in glasses.
- USB-C unplug/reconnect continuity.
- End-to-end pointer/scroll/gesture latency and feel.
- Bluetooth keyboard/mouse behavior, including Command-M and the broader shortcut layer.
- Password AutoFill, passkeys, CAPTCHA, file picker, and provider handoff on real services.
- YouTube/ChatGPT login and playback.
- Long-session battery, thermal, memory, and WebKit behavior.

## Next rotation

Return to **Focus 1 — external-display/RayNeo fidelity**, selecting the highest-impact unfinished readiness blocker in that area rather than adding novelty work.
