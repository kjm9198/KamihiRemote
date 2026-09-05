# Focus 9 — Performance / energy — Sheets persistence

## Readiness audit

Canonical product direction remains the one persistent iPhone desktop from `NATIVE_DESKTOP_GOAL.md`; legacy startup-profile/workspace UI must not be restored. Kamihi Desktop is still **NOT READY** overall.

The highest-impact unfinished readiness blocker overall is now **Sheets daily usability** rather than Sheets being absent: the native grid exists, but useful import/export reachability and richer spreadsheet behavior still need work. Inside Focus 9, the most immediate performance regression introduced by the new Sheets foundation was synchronous full-workbook persistence on every workbook mutation, including each typed character and selection change.

## Change

Source commit: `0c6e25e91943e84f3bb07079cade601f716345b4` — `perf: coalesce Sheets persistence writes`.

- Replaced `Workbook.didSet { save() }` with a 400 ms trailing one-shot persistence task.
- Rapid cell typing, Backspace, Return/selection changes now collapse into one encoded `UserDefaults` write instead of re-encoding the full workbook on every mutation.
- Backgrounding or app termination cancels the pending task and flushes immediately, so the final editing burst is not intentionally left only in memory.
- No repeating timer, display link, polling loop, network path, Mac host, or Remote-for-Mac behavior was added.

## Verification

For source SHA `0c6e25e91943e84f3bb07079cade601f716345b4`:

- Apple Build: PASS on attempt 1.
- Desktop Simulator Smoke / Apple Integration Smoke: PASS on attempt 1.
- Trackpad-first controller contract: PASS.
- Core Kamihi Desktop simulator smoke: PASS.
- Smoke evidence upload: PASS.

No Desktop Lab visual comparison was required because rendered UI and pointer/input geometry were unchanged.

## Remaining performance blocker

Browser/WebKit lifecycle is still only PARTIAL. Memory-warning/background cleanup and Low Power warm-pool limits exist, but the roadmap still calls out a deliberate long-idle inactive-WebView policy and physical memory/thermal profiling. That remains the next performance-specific blocker.

## Next rotation

Focus 10 — keyboard/accessibility/final polish. Choose the highest-impact unfinished readiness blocker in that area; do not add novelty features.

## Physical-only checks

Remain **NEEDS PHYSICAL TEST**: actual RayNeo negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer/hold-to-move feel, Bluetooth keyboard/mouse, real Password AutoFill/passkeys/CAPTCHA/file picker flows, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
