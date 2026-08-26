#!/usr/bin/env bash
# Kamihi Remote — iOS Simulator UI smoke captures (Debug build required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED:-/tmp/KamihiDerivedAudit}"
SIM="${SIM:-iPhone 17}"
OUT="${OUT:-/tmp/kamihi-ui-shots}"
BUNDLE=com.kamihi.remote

if ! xcrun simctl list devices available | grep -Fq "$SIM ("; then
  SIM="$(xcrun simctl list devices available | sed -n 's/^[[:space:]]*\(iPhone[^()]\+\) ([0-9A-F-]\{36\}) (Shutdown)$/\1/p' | head -1 | sed 's/[[:space:]]*$//')"
fi

if [[ -z "$SIM" ]]; then
  echo "No available iPhone simulator found" >&2
  exit 1
fi

echo "Using simulator: $SIM"
echo "Building KamihiRemote (Debug)…"
xcodebuild -project "$ROOT/KamihiRemote.xcodeproj" -scheme KamihiRemote \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$DERIVED" -configuration Debug CODE_SIGNING_ALLOWED=NO build >/dev/null

UDID="$(xcrun simctl list devices available | grep "$SIM (" | head -1 | grep -o -E '[0-9A-F-]{36}')"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"

launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep 2
}

shot() {
  xcrun simctl io "$UDID" screenshot "$OUT/$1"
  echo "  → $OUT/$1"
}

echo "Capturing AppShell screens…"
launch --args -KamihiUITestTab present && shot iphone-present.png
launch --args -KamihiUITestTab deck && shot iphone-deck.png
launch --args -KamihiUITestDeckGallery && shot iphone-deck-gallery.png
launch --args -KamihiUITestKeyboard && shot iphone-keyboard-overlay.png
launch --args -KamihiUITestTab controller && shot iphone-portrait-controller.png

# Simulator menu automation can block indefinitely on headless CI runners because
# System Events may wait for GUI automation permission. Keep landscape capture for
# local audits, but make CI smoke fully non-interactive and deterministic.
if [[ "${CI:-false}" != "true" ]]; then
  osascript <<'OSA' >/dev/null || true
tell application "Simulator" to activate
delay 0.3
tell application "System Events"
  tell process "Simulator"
    click menu item "Rotate Left" of menu "Device" of menu bar item "Device" of menu bar 1
  end tell
end tell
OSA
  sleep 1
  launch --args -KamihiUITestTab controller && shot iphone-landscape-controller.png
fi

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl shutdown "$UDID" 2>/dev/null || true

echo "Done. Screenshots in $OUT"
