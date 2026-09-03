#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
SIM_LOG="$SMOKE_DIR/simulator-launch.log"
RESULT_FILE="$SMOKE_DIR/result.txt"
DEVICE_FILE="$SMOKE_DIR/simulator-devices.txt"
IOS_SYSTEM_LOG="$SMOKE_DIR/ios-system.log"
UDID=""
SIM_NAME=""

mkdir -p "$SMOKE_DIR"
rm -rf "$DERIVED_IOS"
: > "$SIM_LOG"
cd "$ROOT_DIR"

capture_screen() {
  local output="$1"
  local attempt=1
  while (( attempt <= 3 )); do
    if xcrun simctl io "$UDID" screenshot "$output" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done
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
  while (( poll <= 12 )); do
    capture_screen "$output"
    local size
    size="$(screenshot_size_bytes "$output")"
    if (( size >= minimum_bytes )); then
      echo "Desktop Lab screenshot ready (${size} bytes) on visual poll $poll"
      return 0
    fi
    sleep 1
    poll=$((poll + 1))
  done
  echo "Desktop Lab never produced non-blank visual evidence"
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
  if [[ -n "$UDID" ]]; then
    xcrun simctl spawn "$UDID" log show --last 5m --style compact --predicate 'process == "KamihiRemote"' 2>/dev/null \
      | tail -1000 > "$IOS_SYSTEM_LOG" || true
  fi
}

cleanup() {
  local status=$?
  set +e
  collect_diagnostics "$status"
  if [[ -n "$UDID" ]]; then
    xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  fi
  return "$status"
}
trap cleanup EXIT

echo "==> Building Kamihi Desktop for iPhone Simulator"
xcodebuild \
  -project KamihiRemote.xcodeproj \
  -scheme KamihiRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_IOS" \
  ENABLE_PREVIEWS=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

IOS_APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
[[ -d "$IOS_APP" ]] || { echo "Simulator app missing"; exit 1; }

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

if ! boot_simulator; then
  echo "Initial simulator boot failed; erasing and retrying once"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl erase "$UDID" >/dev/null 2>&1 || true
  boot_simulator
fi

xcrun simctl install "$UDID" "$IOS_APP"

echo "==> Launching Kamihi Desktop Lab"
xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.kamihi.remote -KamihiDesktopLab >> "$SIM_LOG" 2>&1
sleep 2

capture_desktop_lab_screen "$SMOKE_DIR/desktop-lab.png"

if ! xcrun simctl spawn "$UDID" launchctl print system 2>/dev/null | grep -q 'com.kamihi.remote'; then
  # launchctl output differs across runtimes; use process lookup as the final assertion.
  xcrun simctl spawn "$UDID" ps -A 2>/dev/null | grep -q 'KamihiRemote' || {
    echo "Kamihi Desktop process is not running"
    exit 1
  }
fi

echo "KAMIHI_DESKTOP_SMOKE_OK" | tee "$SMOKE_DIR/desktop-smoke.txt"
