# Focus 3 — Trackpad / pointer: finger-transition isolation

## Readiness audit

**Verdict: NOT READY.** Kamihi Desktop is materially closer to the intended iPadOS-quality controller behavior, but daily-use completeness is still limited most by Sheets import/export/editing depth and physical RayNeo validation remains outstanding.

The canonical product remains **one persistent desktop**. Older startup-profile/workspace wording is superseded by `NATIVE_DESKTOP_GOAL.md` and must not be restored.

## Highest-impact issue in this rotation

A multi-touch gesture could leak into another gesture role when fingers were lifted one at a time. In particular, a three-finger Overview/window-switch gesture could become an unintended two-finger scroll/resize after one finger lifted. Partial touch-end handling also reset the sampling centroid to `.zero`, which could make the next movement sample appear artificially large.

## Change

Product commit: `40054a017b4c6c4ef6864c036356b5d31e62d830` (`fix: isolate finger-count transitions on trackpad`).

- Partial touch-end transitions now retain the real centroid of the fingers still touching the trackpad and reset the sample timestamp there.
- A gesture that has ever contained three or more fingers cannot become a two-finger scroll/resize gesture until every finger is lifted and a new gesture begins.
- Existing one-finger post-multitouch isolation remains intact.
- Existing deliberate title-bar hold, smooth two-finger scroll ownership, resize hold gate, and finite momentum behavior are preserved.
- No idle timer/display link and no Mac-host/remote product work were added.

## Verification

For `40054a017b4c6c4ef6864c036356b5d31e62d830`:

- Apple Build: passed.
- Desktop Simulator Smoke: passed on **attempt 1**.
- Trackpad-first controller contract: passed.
- Desktop Lab evidence artifact: visually inspected. The one-desktop shell renders normally, the high-contrast pointer is visible, the dock exposes Browser/Documents/Sheets/Files/Notes/ChatGPT, and the iPhone controller remains predominantly a full-screen trackpad with only Keyboard + More persistent controls.
- No rerun or CI-harness workaround was required.

## Remaining

Top software blocker: make native Sheets genuinely useful for daily work with reachable import/export and richer editing/navigation while preserving the simple desktop model.

Next rotation: **Focus 4 — windowing/window management**. Prioritize deterministic close/reopen/focus and intentional movement over workspace novelty.

Physical-only items remain **NEEDS PHYSICAL TEST**: actual RayNeo negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, end-to-end pointer latency and deliberate hold-to-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
