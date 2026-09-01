# Rotation Evidence — Focus 2: iPadOS Shell, Themes & Design System

Date: 2026-09-01

Feature head before this evidence commit: `6ae2808d4b290a790e6e8216d3d287f4172044bf`

## Changes

- Added persisted Kamihi Desktop appearance choices: System, Light, Dark.
- System appearance follows iPhone; Light/Dark can override Kamihi Desktop independently.
- Reworked the original Kamihi atmospheric desktop wallpaper so it has intentional light and dark variants rather than forcing a dark canvas.
- External Desktop and Desktop Lab now apply the chosen desktop color scheme.
- Snap previews, safe-area markers, fallback app surfaces and launcher scrim/shadows now use semantic/adaptive colors.
- Rebuilt the external-display dock around semantic foregrounds, material, adaptive borders/shadows, active/running states and accessibility labels instead of hardcoded dark/white styling.
- Added the appearance picker to Desktop & Display settings alongside RayNeo calibration.

## CI evidence

For feature head `6ae2808`:

- Apple Build: passed on attempt 1.
- GitHub Pages build/deploy: passed.
- Apple Integration Smoke: first attempt was still running when this evidence record was written; it must be re-checked before the next product-quality batch. A rerun without a code change does not count as healthy if attempt 1 fails.

## Next rotation

Focus 3 — Trackpad and pointer quality: acceleration, precision, scroll isolation/momentum, click/right-click/double-click/drag-lock correctness, cursor-state polish, and active-refresh-only rendering.

## Physical-only checks remain

Actual RayNeo Air 4 Pro negotiated resolution/refresh, pointer latency, USB-C reconnect, glasses readability/overscan/HDR, Password AutoFill/passkeys, ChatGPT/YouTube authentication/playback, Bluetooth keyboard/mouse behavior, and long-session battery/thermal performance remain `NEEDS PHYSICAL TEST`.
