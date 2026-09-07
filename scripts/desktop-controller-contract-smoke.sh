#!/usr/bin/env bash
# Deterministic source-level guardrails for the normal Kamihi Desktop phone controller.
# These checks intentionally fail before expensive simulator work if a future edit
# reintroduces retired Remote product UI or weakens keyboard/window/input persistence safety.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROLLER="$ROOT/iOS/Desktop/Controller/DesktopControllerView.swift"
TRACKPAD="$ROOT/iOS/Desktop/Controller/TrackpadEngine.swift"
NOTES_STORE="$ROOT/iOS/Desktop/Apps/Notes/DesktopNotesStore.swift"

fail() {
  echo "desktop-controller-contract: FAIL: $*" >&2
  exit 1
}

require_literal() {
  local needle="$1"
  local message="$2"
  grep -Fq -- "$needle" "$CONTROLLER" || fail "$message"
}

reject_literal() {
  local needle="$1"
  local message="$2"
  if grep -Fq -- "$needle" "$CONTROLLER"; then
    fail "$message"
  fi
}

[[ -f "$CONTROLLER" ]] || fail "DesktopControllerView.swift is missing"
[[ -f "$TRACKPAD" ]] || fail "TrackpadEngine.swift is missing"
[[ -f "$NOTES_STORE" ]] || fail "DesktopNotesStore.swift is missing"

# Normal launch must render the uninterrupted Desktop trackpad directly.
require_literal "fullTrackpadLayout" "normal Desktop controller no longer renders the full trackpad"
reject_literal "if fullTrackpadMode" "normal Desktop controller conditionally exposes an obsolete compact layout"
reject_literal "normalLayout(in: geo.size)" "normal Desktop controller exposes an obsolete preview/dashboard layout"

# Only the two essential controls stay surfaced on the trackpad.
require_literal '.accessibilityLabel(showKeyboard ? "Hide Keyboard" : "Keyboard")' "Keyboard is no longer a first-class trackpad control"
require_literal '.accessibilityLabel("More Desktop Controls")' "secondary controls are no longer tucked behind More"

# Keyboard input is pinned to the window that owned focus when it opened.
require_literal "@State private var keyboardWindowID: UUID?" "keyboard target window is not explicitly captured"
require_literal "windowID: keyboardWindowID" "keyboard input bar is not bound to the captured window"
require_literal ".onChange(of: desktop.activeWindowID)" "keyboard does not observe desktop focus changes"
require_literal "setKeyboardVisible(false)" "keyboard focus-change safety dismissal is missing"
require_literal "guard let activeWindowID = desktop.activeWindowID else { return }" "keyboard can open without an active target window"

# Deliberate window movement is a canonical product invariant. The trackpad may
# arm a title-bar drag only after 1.5-2.0 seconds of continuous eligible dwell,
# and normal movement must not retain a shorter synchronous manipulation bypass.
python3 - "$TRACKPAD" <<'PY' || fail "deliberate title-bar hold contract is broken"
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"windowDragHoldDuration:\s*TimeInterval\s*=\s*([0-9.]+)", text)
if match is None:
    raise SystemExit("windowDragHoldDuration is missing")
duration = float(match.group(1))
if not 1.5 <= duration <= 2.0:
    raise SystemExit(f"window drag hold must be 1.5-2.0 seconds, found {duration}")
if "let wantsManipulation =" in text:
    raise SystemExit("short synchronous window-drag bypass returned")
if re.search(r"guard\s+activeFingers\s*==\s*1,\s*dragHoldEligible,", text) is None:
    raise SystemExit("title-bar hold does not require dragHoldEligible")
if re.search(r"self\.activeFingers\s*==\s*1,\s*self\.dragHoldEligible,", text) is None:
    raise SystemExit("title-bar hold completion does not re-check dragHoldEligible")
if "Self.windowDragHoldDuration * 1_000_000_000" not in text:
    raise SystemExit("title-bar timer is not derived from the canonical hold duration")
PY

# Notes persistence must distinguish a valid intentionally-empty collection from
# first launch, and active-note focus must survive process restart. Otherwise a
# user can delete every note only to have deleted content structure silently
# recreated on relaunch, or reopen into the wrong note.
python3 - "$NOTES_STORE" <<'PY' || fail "Notes delete/reopen persistence contract is broken"
import sys

text = open(sys.argv[1], encoding="utf-8").read()
required = [
    '@Published public var activeNoteID: UUID? {',
    'didSet { saveActiveSelection() }',
    'private let activeNoteStorageKey = "kamihi.desktop.notes.active.v1"',
    'if load() {',
    'restoreActiveSelection()',
    'seedWelcomeNote()',
    'private func load() -> Bool',
    'notes = saved',
    'return true',
]
for needle in required:
    if needle not in text:
        raise SystemExit(f"missing Notes persistence guard: {needle}")
if 'if notes.isEmpty {' in text:
    raise SystemExit("empty Notes collection is still treated as first launch")
PY

# Kamihi Remote / Remote for Mac is retired and must never return to this surface.
reject_literal 'Text("Remote for Mac")' "Remote for Mac was reintroduced into Kamihi Desktop"
reject_literal 'Label("Remote for Mac"' "Remote for Mac was reintroduced into Kamihi Desktop"
reject_literal 'RemoteSession' "legacy Remote session dependency was reintroduced into the Desktop controller"

echo "desktop-controller-contract: PASS"
