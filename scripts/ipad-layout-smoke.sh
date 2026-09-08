#!/bin/bash
set -euo pipefail

DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
IOS_APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
IPAD_LOG="$SMOKE_DIR/ipad-simulator-launch.log"
IPAD_RESULT="$SMOKE_DIR/ipad-result.txt"
UDID=""
SIM_NAME=""

mkdir -p "$SMOKE_DIR"
: > "$IPAD_LOG"

[[ -d "$IOS_APP" ]] || {
  echo "iPad smoke requires the simulator app built by apple-integration-smoke.sh"
  exit 1
}

cleanup() {
  local status=$?
  set +e
  {
    echo "exit_status=$status"
    echo "git_sha=${GITHUB_SHA:-local}"
    echo "simulator_udid=$UDID"
    echo "simulator_name=$SIM_NAME"
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$IPAD_RESULT"
  if [[ -n "$UDID" ]]; then
    xcrun simctl spawn "$UDID" log show --last 6m --style compact \
      --predicate 'process == "KamihiRemote" OR subsystem == "com.kamihi.remote"' \
      2>/dev/null | tail -1200 > "$SMOKE_DIR/ipad-system.log" || true
    xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
  fi
  return "$status"
}
trap cleanup EXIT

SIM_SELECTION="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
payload=json.load(sys.stdin)
preferred=[
    "iPad Pro 13-inch (M5)",
    "iPad Pro 13-inch (M4)",
    "iPad Pro 11-inch (M5)",
    "iPad Pro 11-inch (M4)",
    "iPad Air 13-inch (M3)",
    "iPad Air 11-inch (M3)",
]
candidates=[]
for runtime, devices in payload.get("devices", {}).items():
    match=re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match:
        continue
    version=tuple(int(part) for part in match.group(1).split("-"))
    for device in devices:
        name=device.get("name", "")
        if device.get("isAvailable") and name.startswith("iPad"):
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
[[ -n "$UDID" && "$UDID" != "$SIM_SELECTION" ]] || {
  echo "No available iPad Simulator found"
  exit 1
}

echo "==> Using iPad simulator: $SIM_NAME ($UDID)"
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$IOS_APP"

wait_for_marker() {
  local category="$1"
  local marker="$2"
  local label="$3"
  for poll in $(seq 1 30); do
    if xcrun simctl spawn "$UDID" log show --last 3m --style compact \
        --predicate "subsystem == \"com.kamihi.remote\" AND category == \"$category\"" \
        2>/dev/null | grep -Fq "$marker"; then
      echo "$label ready on poll $poll"
      return 0
    fi
    sleep 1
  done
  echo "$label was not observed"
  return 1
}

capture_nonblank() {
  local output="$1"
  local minimum_bytes=80000
  rm -f "$output"
  for poll in $(seq 1 20); do
    if xcrun simctl io "$UDID" screenshot "$output" >/dev/null 2>&1; then
      size="$(stat -f '%z' "$output" 2>/dev/null || stat -c '%s' "$output" 2>/dev/null || echo 0)"
      if (( size >= minimum_bytes )); then
        echo "iPad Desktop Lab screenshot ready (${size} bytes) on poll $poll"
        return 0
      fi
    fi
    sleep 1
  done
  echo "iPad Desktop Lab never produced non-blank visual evidence"
  return 1
}

if ! xcrun simctl launch "$UDID" com.kamihi.remote -KamihiDesktopLab -KamihiCalculatorLifecycleSmoke >> "$IPAD_LOG" 2>&1; then
  echo "Kamihi Desktop failed to launch on iPad Simulator"
  exit 1
fi

sleep 3
wait_for_marker "CalculatorSmoke" "KAMIHI_CALCULATOR_LIFECYCLE_OK" "iPad Calculator lifecycle marker"
capture_nonblank "$SMOKE_DIR/ipad-desktop-lab.png"
echo "KAMIHI_IPAD_CALCULATOR_LIFECYCLE_OK" | tee "$SMOKE_DIR/ipad-calculator-smoke.txt"

xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
if ! xcrun simctl launch "$UDID" com.kamihi.remote -KamihiDesktopLab -KamihiCalculatorPersistenceVerifySmoke >> "$IPAD_LOG" 2>&1; then
  echo "Kamihi Desktop failed to relaunch for Calculator persistence on iPad Simulator"
  exit 1
fi
sleep 2
wait_for_marker "CalculatorSmoke" "KAMIHI_CALCULATOR_PROCESS_RESTART_OK" "iPad Calculator process-restart marker"
capture_nonblank "$SMOKE_DIR/ipad-calculator-process-restart.png"
echo "KAMIHI_IPAD_CALCULATOR_PROCESS_RESTART_OK" | tee "$SMOKE_DIR/ipad-calculator-process-restart-smoke.txt"

# Clipboard has its own iPad app-flow gate. The lifecycle marker proves window
# ownership; the WebView marker proves a focused local WKWebView editor receives
# exactly one handoff through the production Browser input registry; the pointer
# marker is emitted only after the rendered SwiftUI Refresh/Copy/Notes/Paste/
# Share/Clear targets and long-history native scrolling have been exercised.
xcrun simctl terminate "$UDID" com.kamihi.remote >/dev/null 2>&1 || true
if ! xcrun simctl launch "$UDID" com.kamihi.remote -KamihiDesktopLab -KamihiClipboardLifecycleSmoke >> "$IPAD_LOG" 2>&1; then
  echo "Kamihi Desktop failed to relaunch for Clipboard lifecycle on iPad Simulator"
  exit 1
fi
sleep 2
wait_for_marker "ClipboardSmoke" "KAMIHI_CLIPBOARD_LIFECYCLE_OK" "iPad Clipboard lifecycle marker"
wait_for_marker "ClipboardWebViewSmoke" "KAMIHI_CLIPBOARD_WEBVIEW_OK" "iPad Clipboard WebView handoff marker"
wait_for_marker "ClipboardPointerSmoke" "KAMIHI_CLIPBOARD_POINTER_OK" "iPad Clipboard rendered-pointer marker"
capture_nonblank "$SMOKE_DIR/ipad-clipboard-pointer-controls.png"
echo "KAMIHI_IPAD_CLIPBOARD_LIFECYCLE_OK" | tee "$SMOKE_DIR/ipad-clipboard-smoke.txt"
echo "KAMIHI_IPAD_CLIPBOARD_WEBVIEW_OK" | tee "$SMOKE_DIR/ipad-clipboard-webview-smoke.txt"
echo "KAMIHI_IPAD_CLIPBOARD_POINTER_OK" | tee "$SMOKE_DIR/ipad-clipboard-pointer-smoke.txt"

if ! xcrun simctl spawn "$UDID" launchctl print system 2>/dev/null | grep -Fq "com.kamihi.remote"; then
  if ! xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/ipad-desktop-lab-alive.png" >/dev/null 2>&1; then
    echo "Kamihi Desktop did not remain alive on iPad Simulator"
    exit 1
  fi
fi

echo "KAMIHI_IPAD_SMOKE_OK" | tee "$SMOKE_DIR/ipad-smoke.txt"
