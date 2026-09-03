#!/usr/bin/env bash
# Deterministic source-level guardrails for the normal Kamihi Desktop phone controller.
# These checks intentionally fail before expensive simulator work if a future edit
# reintroduces retired Remote product UI or weakens keyboard target safety.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROLLER="$ROOT/iOS/Desktop/Controller/DesktopControllerView.swift"

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

# Kamihi Remote / Remote for Mac is retired and must never return to this surface.
reject_literal 'Text("Remote for Mac")' "Remote for Mac was reintroduced into Kamihi Desktop"
reject_literal 'Label("Remote for Mac"' "Remote for Mac was reintroduced into Kamihi Desktop"
reject_literal 'RemoteSession' "legacy Remote session dependency was reintroduced into the Desktop controller"

echo "desktop-controller-contract: PASS"
