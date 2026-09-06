# Focus 2 — App Library empty-search recovery

Date: 2026-09-06

## Readiness verdict

NOT READY.

Kamihi Desktop remains on the canonical one-persistent-desktop path in `NATIVE_DESKTOP_GOAL.md`. The legacy startup-profile chooser and Remote-for-Mac product path stay retired from the normal user experience.

At the start of this run, `main` was `984d0bb448c283f1d73868b1aacabc5542e5b108`. Apple Build and Apple Integration Smoke were green. Gmail's newest KamihiRemote failure notifications were stale failures for older SHA `ebb260a`.

## Focus area

Rotation Focus 2 — iPadOS-style shell/design system.

## Highest-impact blocker addressed inside this focus

The App Library is a core shell surface. Its search already matched app names, categories and pinned website hosts, but a zero-result search rendered an empty blank area with no explanation or recovery action. On an external display that looks like a broken launcher rather than a deliberate no-results state, and it does not meet the shell/readiness requirement for coherent empty/error/loading states.

## Change

Product commit: `a61944ac19edc74816a4463f1f3268dd8bc2a830` — `fix: give App Library search a clear empty state`.

The App Library now:

- shows a centered `No Apps Found` empty state instead of a blank launcher,
- explains that users can search by app, category or website name,
- exposes a one-action `Clear Search` recovery path,
- keeps the recovery control at the shared 44-point minimum hit target,
- uses SF Symbols and the shared semantic shell palette/elevated-surface modifier,
- keeps VoiceOver semantics and an explicit recovery hint,
- preserves System/Light/Dark and Reduce Transparency behavior through the existing design system.

No Mac-host, pairing, networking or remote-control product path was touched.

## Verification

For exact product SHA `a61944ac19edc74816a4463f1f3268dd8bc2a830`:

- Apple Build: PASS on run attempt 1.
- Apple Integration Smoke / Desktop Simulator Smoke: simulator smoke PASS on run attempt 1.
- Trackpad-first controller contract: PASS.
- Smoke evidence upload: PASS.
- No rerun, retry or harness workaround was used.

A separate Desktop Lab screenshot pass was not required for this small, localized empty-search state. It does not alter desktop geometry, window management, pointer/input routing, normal launcher layout or controller layout. The product SHA still passed the normal simulator runtime/evidence path.

## Top remaining software blocker

Overall readiness remains constrained most by everyday productivity depth. Documents and Sheets exist, and Sheets now exposes CSV import/export plus VoiceOver-selectable cells, but spreadsheet work still needs richer range-oriented editing such as multi-cell selection/copy-paste, practical row/column operations and lightweight formulas before Kamihi feels like a dependable everyday computer replacement.

The next rotation is Focus 3 — trackpad/pointer, selecting the highest-impact unfinished pointer-readiness blocker rather than adding novelty.

## NEEDS PHYSICAL TEST

- Actual iOS-negotiated RayNeo Air 4 Pro resolution and refresh ceiling.
- Overscan and text readability through the glasses.
- USB-C unplug/reconnect behavior on real hardware.
- End-to-end pointer latency and feel, including deliberate window movement.
- Bluetooth keyboard/mouse behavior.
- Password AutoFill, passkeys, CAPTCHA and file picker against real services.
- YouTube/ChatGPT login and playback.
- Long-session battery and thermal behavior.
