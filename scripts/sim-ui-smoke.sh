#!/usr/bin/env bash
# Kamihi Remote — iOS Simulator UI smoke captures (Debug build required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED:-/tmp/KamihiDerivedAudit}"
SIM="${SIM:-iPhone 17}"
OUT="${OUT:-/tmp/kamihi-ui-shots}"
BUNDLE=com.kamihi.remote

echo "Building KamihiRemote (Debug)…"
xcodebuild -project "$ROOT/KamihiRemote.xcodeproj" -scheme KamihiRemote \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$DERIVED" -configuration Debug build >/dev/null

UDID="$(xcrun simctl list devices available | rg "$SIM \(" | head -1 | rg -o '[0-9A-F-]{36}')"
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

echo "Done. Screenshots in $OUT"
