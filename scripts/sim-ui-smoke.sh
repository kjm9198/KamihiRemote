#!/usr/bin/env bash
# Kamihi Remote — iOS Simulator UI smoke captures (Debug build required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED:-/tmp/KamihiDerivedAudit}"
SIM="${SIM:-iPhone 17}"
OUT="${OUT:-/tmp/kamihi-ui-shots}"
BUNDLE=com.kamihi.remote
SKIP_BUILD="${SKIP_BUILD:-0}"

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "Building KamihiRemote (Debug)…"
  xcodebuild -project "$ROOT/KamihiRemote.xcodeproj" -scheme KamihiRemote \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath "$DERIVED" -configuration Debug \
    CODE_SIGNING_ALLOWED=NO build >/dev/null
fi

# GitHub's macOS runner does not guarantee ripgrep (`rg`) is installed.
# Keep this smoke test dependency-free by using system tools only.
DEVICE_LINE="$(xcrun simctl list devices available | grep -F "$SIM (" | head -1 || true)"
UDID="$(printf '%s\n' "$DEVICE_LINE" | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
if [[ -z "$UDID" ]]; then
  echo "error: Could not find an available '$SIM' simulator." >&2
  xcrun simctl list devices available >&2
  exit 1
fi

APP="$DERIVED/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
if [[ ! -d "$APP" ]]; then
  echo "error: Simulator app not found at $APP" >&2
  exit 1
fi
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
BOOTED=0
for _ in $(seq 1 90); do
  if xcrun simctl list devices | grep -F "$UDID" | grep -q '(Booted)'; then
    BOOTED=1
    break
  fi
  sleep 1
done
if [[ "$BOOTED" != "1" ]]; then
  echo "error: Simulator '$SIM' did not boot within 90 seconds." >&2
  xcrun simctl list devices >&2
  exit 1
fi

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
launch --args -KamihiUITestTab controller && shot iphone-controller.png

echo "Done. Screenshots in $OUT"
