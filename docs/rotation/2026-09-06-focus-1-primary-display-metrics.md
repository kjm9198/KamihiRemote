# Focus 1 — Primary external-display metrics ownership

Date: 2026-09-06

## Readiness verdict

NOT READY.

Kamihi Desktop remains on the canonical one-persistent-desktop path from `NATIVE_DESKTOP_GOAL.md`. The legacy startup-profile chooser and Remote-for-Mac product path must stay out of the normal user experience.

The baseline `6f434ac84c952f1df2a924944d28b0e0b8b1982c` was green on Apple Build and Apple Integration Smoke. Gmail's newest KamihiRemote failure notifications were stale `ebb260a` failures from an older corrected commit.

## Focus area

Rotation Focus 1 — external-display / RayNeo fidelity.

## Highest-impact blocker addressed

Fast USB-C unplug/replug can briefly leave the retiring external-display scene and its replacement alive at the same time. Scene ownership already prevented a late disconnect from falsely disconnecting the whole desktop, but the retiring scene could still receive a geometry callback and overwrite the shared `ExternalDisplayCoordinator` resolution, backing-scale, and refresh diagnostics after the replacement scene had become the active display.

That race could leave the iPhone controller describing the wrong negotiated output until the newer scene happened to update again.

## Change

Product commit: `df3b08e61e0f9ad8f40bd1a012de3e467ba3caa8` — `fix: keep display metrics on newest external scene`.

`ExternalDisplaySceneDelegate` now:

- treats the most recently connected external scene as the owner of shared display metrics,
- records the latest public UIKit screen/logical-size measurements for every live external scene,
- ignores stale shared-metric refreshes from older overlapping scenes while still allowing each scene to size its own window correctly,
- falls back to another still-live scene's cached metrics if the current primary disappears,
- preserves the existing last-scene-only disconnect behavior.

No display mode is forced, no 120 Hz claim is introduced, and no Mac-host/remote path was touched.

## Verification

For exact product SHA `df3b08e61e0f9ad8f40bd1a012de3e467ba3caa8`:

- Apple Build: PASS.
- Apple Integration Smoke / Desktop Simulator Smoke: PASS on run attempt 1.
- Trackpad-first controller contract: PASS.
- Kamihi Desktop simulator smoke: PASS.
- Smoke evidence upload: PASS.
- No rerun, retry, or CI harness workaround was used.

A separate Desktop Lab screenshot comparison was not required for this lifecycle/metrics ownership fix because it intentionally changes no rendered layout, pointer geometry, typography, or visible interaction surface. The integration smoke evidence remains the automated UI/runtime evidence for the product SHA.

## Top remaining software blocker

Overall readiness is still most constrained by everyday productivity depth. Documents/Sheets are present and Sheets now exposes CSV import/export plus VoiceOver-selectable cells, but spreadsheet work still needs richer range-oriented editing such as multi-cell selection/copy-paste, efficient row/column operations, and lightweight formulas before it feels like a dependable everyday computer replacement.

The next rotation is Focus 2 — iPadOS-style shell/design system, choosing the highest-impact unfinished readiness blocker inside that area rather than adding novelty.

## NEEDS PHYSICAL TEST

- Actual iOS-negotiated RayNeo Air 4 Pro resolution and refresh ceiling.
- Overscan and text readability through the glasses.
- USB-C unplug/reconnect behavior on real hardware, including rapid reconnect overlap.
- End-to-end pointer latency and deliberate window-move feel.
- Bluetooth keyboard/mouse behavior.
- Password AutoFill, passkeys, CAPTCHA, and file picker against real services.
- YouTube/ChatGPT login and playback.
- Long-session battery and thermal behavior.
