#!/usr/bin/env bash
# Kamihi Remote - iOS Simulator launch smoke + optional screenshot evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED:-/tmp/KamihiDerivedAudit}"
SIM="${SIM:-iPhone 17}"
OUT="${OUT:-/tmp/kamihi-ui-shots}"
BUNDLE=com.kamihi.remote
SKIP_BUILD="${SKIP_BUILD:-0}"

run_bounded() {
  local seconds="$1"
  shift
  "$@" &
  local pid=$!
  local elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= seconds )); then
      echo "error: command timed out after ${seconds}s: $*" >&2
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
}

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "Building KamihiRemote (Debug)..."
  xcodebuild -project "$ROOT/KamihiRemote.xcodeproj" -scheme KamihiRemote \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath "$DERIVED" -configuration Debug \
    CODE_SIGNING_ALLOWED=NO build >/dev/null
fi

# GitHub's macOS runner does not guarantee ripgrep (rg) is installed.
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

run_bounded 20 xcrun simctl boot "$UDID" 2>/dev/null || true
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

run_bounded 30 xcrun simctl install "$UDID" "$APP"

launch() {
  local label="$1"
  shift
  run_bounded 10 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  echo "Launching ${label}..."
  run_bounded 20 xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep 2
}

shot() {
  local name="$1"
  if run_bounded 15 xcrun simctl io "$UDID" screenshot "$OUT/$name"; then
    echo "  -> $OUT/$name"
  else
    echo "warning: screenshot unavailable for $name; launch verification still passed" >&2
  fi
}

echo "Running AppShell launch smoke..."
launch "Present" --args -KamihiUITestTab present
shot iphone-present.png
launch "Deck" --args -KamihiUITestTab deck
shot iphone-deck.png
launch "Deck Gallery" --args -KamihiUITestDeckGallery
shot iphone-deck-gallery.png
launch "Keyboard Overlay" --args -KamihiUITestKeyboard
shot iphone-keyboard-overlay.png
launch "Controller" --args -KamihiUITestTab controller
shot iphone-controller.png

echo "Simulator launch smoke passed. Evidence directory: $OUT"
