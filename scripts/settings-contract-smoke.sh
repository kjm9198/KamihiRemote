#!/bin/bash
set -euo pipefail

SETTINGS="iOS/Desktop/Apps/Settings/DesktopSettingsAppView.swift"

fail() {
  echo "Settings contract failed: $1" >&2
  exit 1
}

[[ -f "$SETTINGS" ]] || fail "missing $SETTINGS"

grep -Fq 'case "autohideDock":' "$SETTINGS" || fail "Dock auto-hide action handler missing"
grep -Fq 'desktop.autohideDock.toggle()' "$SETTINGS" || fail "Dock auto-hide action no longer toggles the setting"
grep -Fq 'Automatically hide and show the Dock' "$SETTINGS" || fail "Dock auto-hide setting row missing"
grep -Fq 'button(s.autohideDock ? "Keep Dock Visible" : "Hide Dock Automatically",action:"autohideDock",value:"")' "$SETTINGS" || fail "Dock action copy no longer matches toggle semantics"

if grep -Fq 'Turn Off Dock' "$SETTINGS"; then
  fail "misleading Turn Off Dock copy returned"
fi

echo "Settings action contract OK"
