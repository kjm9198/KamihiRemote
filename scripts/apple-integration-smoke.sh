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
RESULT_FILE="$SMOKE_DIR/result.txt"
DEVICE_FILE="$SMOKE_DIR/simulator-devices.txt"
PORT_FILE="$SMOKE_DIR/port-state.txt"
IOS_SYSTEM_LOG="$SMOKE_DIR/ios-system.log"
HOST_PID=""
UDID=""
SIM_NAME=""

mkdir -p "$SMOKE_DIR"
rm -rf "$DERIVED_IOS" "$DERIVED_MAC"
: > "$HOST_LOG"
: > "$SIM_LOG"

cd "$ROOT_DIR"

retry_command() {
  local attempts="$1"
  local delay="$2"
  shift 2
  local attempt=1
  while (( attempt <= attempts )); do
    if "$@"; then
      return 0
    fi
    if (( attempt == attempts )); then
      return 1
    fi
    echo "Retrying command after failure ($attempt/$attempts): $*"
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

capture_screen() {
  local output="$1"
  local attempt=1
  while (( attempt <= 3 )); do
    if xcrun simctl io "$UDID" screenshot "$output" >/dev/null 2>&1; then
      return 0
    fi
    echo "Screenshot attempt $attempt failed for $output"
    sleep 1
    attempt=$((attempt + 1))
  done
  echo "Unable to capture simulator screenshot: $output"
  return 1
}

screenshot_size_bytes() {
  local path="$1"
  stat -f '%z' "$path" 2>/dev/null || stat -c '%s' "$path"
}

capture_desktop_lab_screen() {
  local output="$1"
  local minimum_bytes=120000
  local poll=1

  # Desktop Lab readiness is intentionally determined from the rendered output
  # itself. App-sandbox UserDefaults are not a reliable cross-process readiness
  # channel for `simctl spawn defaults` on hosted runners. Polling screenshots is
  # bounded visual-evidence infrastructure only; it never retries build, auth,
  # protocol, or product assertions.
  while (( poll <= 12 )); do
    capture_screen "$output"
    local size
    size="$(screenshot_size_bytes "$output")"
    if (( size >= minimum_bytes )); then
      echo "Desktop Lab screenshot evidence ready (${size} bytes) on visual poll $poll"
      return 0
    fi
    echo "Desktop Lab screenshot blank/under-rendered (${size} bytes) on visual poll $poll/12"
    sleep 1
    poll=$((poll + 1))
  done

  echo "Desktop Lab never produced non-blank visual evidence"
  xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "KamihiRemote"' 2>/dev/null | tail -250 || true
  return 1
}

launch_sim_app() {
  local attempt=1
  xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  while (( attempt <= 2 )); do
    echo "==> Simulator launch attempt $attempt: $*" >> "$SIM_LOG"
    if xcrun simctl launch "$UDID" com.kamihi.remote "$@" >> "$SIM_LOG" 2>&1; then
      return 0
    fi
    echo "Simulator launch attempt $attempt failed" | tee -a "$SIM_LOG"
    xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
    sleep 1
    attempt=$((attempt + 1))
  done
  cat "$SIM_LOG" || true
  return 1
}

collect_diagnostics() {
  local status="$1"
  {
    echo "exit_status=$status"
    echo "git_sha=${GITHUB_SHA:-local}"
    echo "simulator_udid=$UDID"
    echo "simulator_name=$SIM_NAME"
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$RESULT_FILE"

  xcrun simctl list devices > "$DEVICE_FILE" 2>&1 || true
  lsof -nP -iTCP:"$TCP_PORT" -sTCP:LISTEN > "$PORT_FILE" 2>&1 || true

  if [[ "$status" -ne 0 && -n "$UDID" ]]; then
    xcrun simctl spawn "$UDID" log show --last 5m --style compact --predicate 'process == "KamihiRemote"' 2>/dev/null \
      | tail -1000 > "$IOS_SYSTEM_LOG" || true
    capture_screen "$SMOKE_DIR/failure-screen.png" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  local status=$?
  set +e
  collect_diagnostics "$status"
  if [[ -n "$UDID" ]]; then
    xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  fi
  if [[ -n "$HOST_PID" ]]; then
    kill "$HOST_PID" >/dev/null 2>&1 || true
  fi
  pkill -9 -x KamihiRemoteHost >/dev/null 2>&1 || true
  return "$status"
}
trap cleanup EXIT

pkill -9 -x KamihiRemoteHost >/dev/null 2>&1 || true

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
MAC_EXEC="$HOST_APP/Contents/MacOS/KamihiRemoteHost"
IOS_APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"

[[ -x "$MAC_EXEC" ]] || { echo "Host executable missing"; exit 1; }
[[ -d "$IOS_APP" ]] || { echo "Simulator app missing"; exit 1; }
codesign -s - --force --deep "$HOST_APP" >/dev/null 2>&1 || true

# Pick a deterministic simulator from the newest available iOS runtime instead
# of relying on CoreSimulator JSON dictionary order.
SIM_SELECTION="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
payload=json.load(sys.stdin)
preferred=["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro"]
candidates=[]
for runtime, devices in payload.get("devices", {}).items():
    match=re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match:
        continue
    version=tuple(int(part) for part in match.group(1).split("-"))
    for device in devices:
        name=device.get("name", "")
        if device.get("isAvailable") and name.startswith("iPhone"):
            rank=preferred.index(name) if name in preferred else len(preferred)
            candidates.append((version, rank, name, device["udid"]))
if not candidates:
    raise SystemExit(1)
latest=max(item[0] for item in candidates)
choices=[item for item in candidates if item[0] == latest]
choices.sort(key=lambda item: (item[1], item[2]))
_, _, name, udid=choices[0]
print(f"{udid}|{name}")
')"

UDID="${SIM_SELECTION%%|*}"
SIM_NAME="${SIM_SELECTION#*|}"
[[ -n "$UDID" && "$UDID" != "$SIM_SELECTION" ]] || { echo "No available iPhone Simulator found"; exit 1; }
echo "==> Using $SIM_NAME ($UDID)"

boot_simulator() {
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b
}

# CoreSimulator occasionally gets stuck in first-boot migration on hosted
# runners. Retry once from a clean device only if the normal boot actually
# fails; do not erase a healthy simulator on every run.
if ! boot_simulator; then
  echo "Initial simulator boot failed; erasing and retrying once"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID" >/dev/null 2>&1 || true
  boot_simulator
fi

# Seed deterministic pairing on both sides. Loopback avoids Bonjour/local
# network discovery flakiness while still exercising the real TCP path.
defaults write com.kamihi.remote.host pairingCode -string "$PAIR_CODE"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote pairingCode -string "$PAIR_CODE"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote hostAddress -string "127.0.0.1"
xcrun simctl spawn "$UDID" defaults write com.kamihi.remote hostPort -int "$UDP_PORT"

start_host() {
  local attempt=1
  while (( attempt <= 3 )); do
    pkill -9 -x KamihiRemoteHost >/dev/null 2>&1 || true
    sleep 1
    echo "==> Host launch attempt $attempt" | tee -a "$HOST_LOG"
    NSUnbufferedIO=YES "$MAC_EXEC" >> "$HOST_LOG" 2>&1 &
    HOST_PID=$!

    local poll=1
    while (( poll <= 180 )); do
      if nc -z 127.0.0.1 "$TCP_PORT" >/dev/null 2>&1; then
        echo "Host TCP $TCP_PORT ready on attempt $attempt"
        return 0
      fi
      if ! kill -0 "$HOST_PID" >/dev/null 2>&1; then
        echo "Host exited before opening TCP on attempt $attempt" | tee -a "$HOST_LOG"
        break
      fi
      sleep 0.25
      poll=$((poll + 1))
    done

    echo "Host did not become ready on attempt $attempt" | tee -a "$HOST_LOG"
    kill "$HOST_PID" >/dev/null 2>&1 || true
    HOST_PID=""
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "Mac host never opened TCP $TCP_PORT after bounded retries"
  cat "$HOST_LOG" || true
  return 1
}

echo "==> Launching real macOS host"
start_host

echo "==> Probing reliable-channel authentication"
: > "$AUTH_RESPONSE"
printf '000000 REQUEST_ACTIVE_APP\n' | nc -w 1 127.0.0.1 "$TCP_PORT" > "$AUTH_RESPONSE" 2>/dev/null || true
for _ in $(seq 1 40); do
  if grep -q "Kamihi rejected unauthenticated TCP command: REQUEST_ACTIVE_APP" "$HOST_LOG"; then
    break
  fi
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

echo "==> Installing real iPhone app"
xcrun simctl uninstall "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
retry_command 2 2 xcrun simctl install "$UDID" "$IOS_APP"
xcrun simctl privacy "$UDID" grant local-network com.kamihi.remote >/dev/null 2>&1 || true

# A client-launch failure can be simulator infrastructure rather than product
# behavior. Allow one bounded relaunch, but never retry protocol assertions once
# a session has actually handshaken.
echo "==> Launching iPhone app and waiting for authenticated handshake"
HANDSHAKE_OK=0
SYNC_DELTA=0
CLIENT_ATTEMPT=1
while (( CLIENT_ATTEMPT <= 2 )); do
  BASELINE_SYNC_COUNT="$(grep -c "Kamihi updated controller mapping profile" "$HOST_LOG" || true)"
  launch_sim_app -pairingCode "$PAIR_CODE" -hostAddress "127.0.0.1"

  for _ in $(seq 1 60); do
    CURRENT_SYNC_COUNT="$(grep -c "Kamihi updated controller mapping profile" "$HOST_LOG" || true)"
    if (( CURRENT_SYNC_COUNT > BASELINE_SYNC_COUNT )); then
      HANDSHAKE_OK=1
      break
    fi
    if ! kill -0 "$HOST_PID" >/dev/null 2>&1; then
      echo "Mac host crashed during handshake"
      break
    fi
    sleep 0.5
  done

  if [[ "$HANDSHAKE_OK" -eq 1 ]]; then
    sleep 1
    FINAL_SYNC_COUNT="$(grep -c "Kamihi updated controller mapping profile" "$HOST_LOG" || true)"
    SYNC_DELTA=$((FINAL_SYNC_COUNT - BASELINE_SYNC_COUNT))
    break
  fi

  echo "Handshake launch attempt $CLIENT_ATTEMPT did not complete; retrying the client once if possible"
  xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  sleep 2
  CLIENT_ATTEMPT=$((CLIENT_ATTEMPT + 1))
done

if [[ "$HANDSHAKE_OK" -ne 1 ]]; then
  echo "iPhone Simulator did not complete a Kamihi handshake with the Mac host"
  capture_screen "$SMOKE_DIR/handshake-failure.png" >/dev/null 2>&1 || true
  echo "--- host log ---"
  cat "$HOST_LOG" || true
  echo "--- recent simulator app log ---"
  xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "KamihiRemote"' 2>/dev/null | tail -250 || true
  exit 1
fi

# A single connected client session must emit one mapping sync. The baseline is
# reset for each bounded launch attempt so an infrastructure retry does not look
# like an application duplicate-handshake regression.
echo "$SYNC_DELTA" > "$SMOKE_DIR/initial-controller-sync-count.txt"
if [[ "$SYNC_DELTA" -ne 1 ]]; then
  echo "Expected exactly one controller-config sync for the successful handshake, got $SYNC_DELTA"
  cat "$HOST_LOG" || true
  exit 1
fi

echo "==> End-to-end authenticated handshake PASS"
capture_screen "$SMOKE_DIR/connected-trackpad.png"

visual_smoke() {
  local label="$1"
  local wait_seconds="$2"
  local screenshot="$3"
  shift 3
  echo "==> $label"
  launch_sim_app "$@"
  sleep "$wait_seconds"
  capture_screen "$SMOKE_DIR/$screenshot"
}

desktop_lab_visual_smoke() {
  echo "==> Kamihi Desktop Lab visual smoke"
  launch_sim_app -KamihiDesktopLab
  capture_desktop_lab_screen "$SMOKE_DIR/desktop-lab.png"
}

# First-class user-facing surfaces.
visual_smoke "Mode chooser visual smoke" 2 "mode-chooser.png" -KamihiModeChooser
desktop_lab_visual_smoke

# Hidden legacy Remote-for-Mac paths stay covered as regression protection even
# though they are no longer normal product-launch compartments.
visual_smoke "Controller workspace regression smoke" 3 "controller.png" -KamihiUITestTab controller
visual_smoke "Vibe workspace regression smoke" 3 "vibe.png" -KamihiUITestTab vibe
visual_smoke "Deck gallery regression smoke" 3 "deck.png" -KamihiUITestDeckGallery

kill -0 "$HOST_PID" >/dev/null 2>&1 || { echo "Mac host did not survive smoke test"; exit 1; }
nc -z 127.0.0.1 "$TCP_PORT" >/dev/null 2>&1 || { echo "Mac host TCP listener disappeared during smoke test"; exit 1; }

echo "==> Kamihi iPhone + Mac + Desktop Lab integration smoke PASS"
