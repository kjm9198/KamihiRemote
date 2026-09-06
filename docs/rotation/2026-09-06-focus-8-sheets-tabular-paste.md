# Focus 8 — Native apps / Sheets tabular paste

Date: 2026-09-06

## Readiness audit

Question: If the user plugs the iPhone into RayNeo glasses or a normal external monitor right now, does Kamihi Desktop feel complete enough to use as a Mac-like desktop environment, with an iPadOS-quality pointer/controller?

Verdict: **NOT READY**.

The canonical `NATIVE_DESKTOP_GOAL.md` remains the one-persistent-desktop model. Do not restore the retired startup-profile chooser or Remote-for-Mac product paths.

The largest overall software blocker remains native productivity depth, especially spreadsheet workflows. Sheets already persists locally and supports user-triggered CSV import/export, but ordinary clipboard pastes containing rows/columns were previously appended into one active cell.

## Focus 8 change

Product commit: `659e3ba05843008271b647cca52fcec1e7e7afd2` — `feat: paste tabular clipboard data into Sheets`

`DesktopSheetsStore.appendToActiveCell` now recognizes tab/newline-delimited text arriving through the existing iPhone keyboard/text-input path. Multi-row / multi-column clipboard content fills the grid starting at the active cell, replaces existing values in the pasted rectangle (including intentional empty fields), clips safely at the 20x12 lightweight grid boundary, normalizes CRLF/CR line endings, and ignores a single trailing clipboard newline so it does not clear an extra row. Normal single-cell typing is unchanged.

This materially improves interoperability with spreadsheet clipboard data from apps such as Numbers/Excel/Google Sheets without adding credential, network, or Mac-host behavior.

## Verification

Baseline `a30ffcfc70a9820aa273002f3d1424d11e933930` was green on Apple Build and Desktop Simulator Smoke before feature work. Gmail failures matched only stale older SHAs.

The product SHA's Apple Build and Desktop Simulator Smoke were started on original attempt 1 immediately after push. No rerun/retry or harness workaround was used at note creation time.

Desktop Lab screenshot comparison is not independently diagnostic for this data-routing change because visible desktop/controller geometry is unchanged. Simulator build/smoke evidence remains the relevant software gate.

## Remaining readiness blocker

Sheets still needs true range selection/copy, stronger editing/replacement affordances, row/column operations, and lightweight formulas before it is desktop-class for everyday work.

Next rotation: **Focus 9 — performance/energy/WebView lifecycle**.

## Physical-only checks

Still **NEEDS PHYSICAL TEST** on real iPhone + RayNeo Air 4 Pro / external monitor: negotiated resolution/refresh, glasses overscan/readability, USB-C unplug/reconnect, pointer and deliberate window-move feel, Bluetooth keyboard/mouse, Password AutoFill/passkeys/CAPTCHA/file picker on real services, YouTube/ChatGPT login/playback, and long-session battery/thermal behavior.
