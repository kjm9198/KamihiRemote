#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PAIR_CODE="654321"
TCP_PORT="49732"
UDP_PORT="49731"
DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
DERIVED_MAC="${RUNNER_TEMP:-/tmp}/kamihi-mac-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
HOST_LOG="$SMOKE_DIR/host.log"
SIM_LOG="$SMOKE_DIR/simulator-launch.log"
AUTH_RESPONSE="$SMOKE_DIR/unauthenticated-response.txt"

pkill -9 -f KamihiRemoteHost >/dev/null 2>&1 || true

mkdir -p "$SMOKE_DIR"
rm -rf "$DERIVED_IOS" "$DERIVED_MAC"

cd "$ROOT_DIR"

echo "==> Building macOS host"
xcodebuild \
  -project KamihiRemote.xcodeproj \
  -scheme KamihiRemoteHost \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath "$DERIVED_MAC" \
  ENABLE_PREVIEWS=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Building iPhone Simulator app"
xcodebuild \
  -project KamihiRemote.xcodeproj \
  -scheme KamihiRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_IOS" \
  ENABLE_PREVIEWS=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

HOST_APP="$DERIVED_MAC/Build/Products/Debug/KamihiRemoteHost.app"
IOS_APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"

[[ -x "$HOST_APP/Contents/MacOS/KamihiRemoteHost" ]] || { echo "Host executable missing"; exit 1; }
[[ -d "$IOS_APP" ]] || { echo "Simulator app missing"; exit 1; }
codesign -s - --force --deep "$HOST_APP" >/dev/null 2>&1 || true

UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
payload=json.load(sys.stdin)
for runtime, devices in payload.get("devices", {}).items():
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print(device["udid"])
            raise SystemExit
')"

[[ -n "$UDID" ]] || { echo "No available iPhone Simulator found"; exit 1; }
echo "==> Using iPhone Simulator $UDID"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b

# Seed the same deterministic pairing code on both apps. The iPhone is told to
# connect directly to the Mac runner's loopback interface, avoiding Bonjour UI
# permission prompts and exercising the real ReliableClient/TCPServer path.
defaults write com.kamihi.remote.host pairingCode -string "$PAIR_CODE"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote pairingCode -string "$PAIR_CODE"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote hostAddress -string "127.0.0.1"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote hostPort -int "$UDP_PORT"

cleanup() {
  set +e
  xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  if [[ -n "${HOST_PID:-}" ]]; then kill "$HOST_PID" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

echo "==> Launching real macOS host"
pkill -9 -f KamihiRemoteHost >/dev/null 2>&1 || true
sleep 1
"$HOST_APP/Contents/MacOS/KamihiRemoteHost" >"$HOST_LOG" 2>&1 &
HOST_PID=$!

for _ in $(seq 1 60); do
  if nc -z 127.0.0.1 "$TCP_PORT"; then break; fi
  if ! kill -0 "$HOST_PID" >/dev/null 2>&1; then
    echo "Mac host exited before opening TCP port"
    cat "$HOST_LOG" || true
    exit 1
  fi
  sleep 0.25
done
nc -z 127.0.0.1 "$TCP_PORT" || { echo "Mac host never opened TCP $TCP_PORT"; cat "$HOST_LOG" || true; exit 1; }

echo "==> Probing reliable-channel authentication"
: > "$AUTH_RESPONSE"
printf '000000 REQUEST_ACTIVE_APP\n' | nc -w 1 127.0.0.1 "$TCP_PORT" >"$AUTH_RESPONSE" 2>/dev/null || true
for _ in $(seq 1 20); do
  if grep -q "Kamihi rejected unauthenticated TCP command: REQUEST_ACTIVE_APP" "$HOST_LOG"; then break; fi
  sleep 0.1
done
if [[ -s "$AUTH_RESPONSE" ]]; then
  echo "Mac responded to an unauthenticated reliable command"
  cat "$AUTH_RESPONSE" || true
  exit 1
fi
grep -q "Kamihi rejected unauthenticated TCP command: REQUEST_ACTIVE_APP" "$HOST_LOG" || {
  echo "Mac did not record rejection of the unauthenticated TCP probe"
  cat "$HOST_LOG" || true
  exit 1
}
echo "==> Unauthenticated reliable command rejected PASS"

echo "==> Installing and launching real iPhone app"
xcrun simctl install "$UDID" "$IOS_APP"
xcrun simctl privacy "$UDID" grant local-network com.kamihi.remote >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.kamihi.remote -pairingCode "$PAIR_CODE" -hostAddress "127.0.0.1" | tee "$SIM_LOG"

# A connected iPhone syncs its controller mapping exactly once when the session
# transitions to connected. The host log is therefore both a handshake sentinel
# and a regression check against duplicate hello/pair acknowledgements.
HANDSHAKE_OK=0
for _ in $(seq 1 60); do
  if grep -q "Kamihi updated controller mapping profile" "$HOST_LOG"; then
    HANDSHAKE_OK=1
    break
  fi
  if ! kill -0 "$HOST_PID" >/dev/null 2>&1; then
    echo "Mac host crashed during handshake"
    break
  fi
  sleep 0.5
done

if [[ "$HANDSHAKE_OK" -ne 1 ]]; then
  echo "iPhone Simulator did not complete a Kamihi handshake with the Mac host"
  xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/handshake-failure.png" >/dev/null 2>&1 || true
  echo "--- host log ---"
  cat "$HOST_LOG" || true
  echo "--- recent simulator app log ---"
  xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "KamihiRemote"' 2>/dev/null | tail -250 || true
  exit 1
fi

sleep 1
INITIAL_SYNC_COUNT="$(grep -c "Kamihi updated controller mapping profile" "$HOST_LOG" || true)"
echo "$INITIAL_SYNC_COUNT" > "$SMOKE_DIR/initial-controller-sync-count.txt"
if [[ "$INITIAL_SYNC_COUNT" -ne 1 ]]; then
  echo "Expected exactly one controller-config sync during initial handshake, got $INITIAL_SYNC_COUNT"
  cat "$HOST_LOG" || true
  exit 1
fi

echo "==> End-to-end authenticated handshake PASS"
xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/connected-trackpad.png"

# Smoke the interaction-heavy workspaces independently so layout/startup
# regressions are caught even when the default trackpad screen is healthy.
echo "==> Controller workspace smoke"
xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.kamihi.remote -KamihiUITestTab controller | tee -a "$SIM_LOG"
sleep 3
xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/controller.png"

echo "==> Vibe workspace smoke"
xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.kamihi.remote -KamihiUITestTab vibe | tee -a "$SIM_LOG"
sleep 3
xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/vibe.png"

echo "==> Deck gallery smoke"
xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.kamihi.remote -KamihiUITestDeckGallery | tee -a "$SIM_LOG"
sleep 3
xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/deck.png"

kill -0 "$HOST_PID" >/dev/null 2>&1 || { echo "Mac host did not survive smoke test"; exit 1; }

echo "==> Kamihi iPhone + Mac integration smoke PASS"
