#!/usr/bin/env bash
set -euo pipefail

DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
BUNDLE="com.kamihi.remote"
mkdir -p "$SMOKE_DIR"

[[ -d "$APP" ]] || { echo "ChatGPT smoke requires the simulator build from apple-integration-smoke.sh"; exit 1; }

# CoreSimulator commands occasionally wedge on hosted macOS runners. Bound only
# infrastructure operations; the actual ChatGPT lifecycle assertion still gets
# exactly one app launch and must emit its own success marker.
bounded() {
  local seconds="$1"
  shift
  python3 - "$seconds" "$@" <<'PY'
import subprocess, sys
seconds=float(sys.argv[1])
cmd=sys.argv[2:]
try:
    completed=subprocess.run(cmd, timeout=seconds)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
raise SystemExit(completed.returncode)
PY
}

pick_device() {
  local family="$1"
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
family=sys.argv[1]
payload=json.load(sys.stdin)
candidates=[]
for runtime, devices in payload.get("devices", {}).items():
    match=re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match:
        continue
    version=tuple(int(part) for part in match.group(1).split("-"))
    for device in devices:
        name=device.get("name", "")
        if device.get("isAvailable") and name.startswith(family):
            candidates.append((version, name, device["udid"]))
if not candidates:
    raise SystemExit(1)
latest=max(item[0] for item in candidates)
choices=sorted(item for item in candidates if item[0] == latest)
_, name, udid=choices[0]
print(f"{udid}|{name}")
' "$family"
}

is_booted() {
  local udid="$1"
  xcrun simctl list devices -j | python3 -c '
import json, sys
udid=sys.argv[1]
payload=json.load(sys.stdin)
for devices in payload.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == udid:
            raise SystemExit(0 if device.get("state") == "Booted" else 1)
raise SystemExit(1)
' "$udid"
}

ensure_simulator_ready() {
  local udid="$1"
  local name="$2"
  local attempt

  if ! is_booted "$udid"; then
    bounded 8 xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  fi

  attempt=1
  while (( attempt <= 45 )); do
    if is_booted "$udid"; then
      break
    fi
    sleep 1
    attempt=$((attempt + 1))
  done
  if ! is_booted "$udid"; then
    echo "Simulator never reached Booted state: $name ($udid)"
    return 1
  fi

  bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  bounded 8 xcrun simctl uninstall "$udid" "$BUNDLE" >/dev/null 2>&1 || true

  attempt=1
  while (( attempt <= 8 )); do
    if bounded 10 xcrun simctl install "$udid" "$APP" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "Simulator became Booted but never accepted app install: $name ($udid)"
  return 1
}

capture_evidence() {
  local udid="$1"
  local slug="$2"
  bounded 6 xcrun simctl io "$udid" screenshot "$SMOKE_DIR/chatgpt-lifecycle-${slug}.png" >/dev/null 2>&1 || true
}

run_family() {
  local family="$1"
  local slug="$2"
  local selection udid name poll log_file stderr_file
  selection="$(pick_device "$family")"
  udid="${selection%%|*}"
  name="${selection#*|}"
  log_file="$SMOKE_DIR/chatgpt-lifecycle-${slug}.log"
  stderr_file="$SMOKE_DIR/chatgpt-lifecycle-${slug}.stderr.log"
  : > "$log_file"
  : > "$stderr_file"
  echo "==> ChatGPT lifecycle smoke on $name ($udid)"

  if ! ensure_simulator_ready "$udid" "$name"; then
    capture_evidence "$udid" "$slug"
    return 1
  fi

  # The DEBUG lifecycle harness deliberately prints its success/failure marker.
  # Capture that app-process output directly instead of querying or streaming the
  # unified log database. This avoids macOS-runner log latency/races while keeping
  # the product assertion single-launch and deterministic.
  if ! bounded 10 xcrun simctl launch \
      --terminate-running-process \
      --stdout="$log_file" \
      --stderr="$stderr_file" \
      "$udid" "$BUNDLE" -KamihiDesktopLab -KamihiChatGPTLifecycleSmoke >/dev/null; then
    echo "ChatGPT lifecycle app launch failed on $name"
    capture_evidence "$udid" "$slug"
    return 1
  fi

  poll=1
  while (( poll <= 30 )); do
    if grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_OK" "$log_file" "$stderr_file" 2>/dev/null; then
      capture_evidence "$udid" "$slug"
      echo "KAMIHI_CHATGPT_LIFECYCLE_OK ($name)"
      bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
      return 0
    fi

    if grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_FAIL" "$log_file" "$stderr_file" 2>/dev/null; then
      echo "ChatGPT lifecycle harness reported failure on $name"
      capture_evidence "$udid" "$slug"
      bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
      return 1
    fi

    sleep 1
    poll=$((poll + 1))
  done

  echo "ChatGPT lifecycle success marker was not observed on $name"
  capture_evidence "$udid" "$slug"
  bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  return 1
}

run_family "iPhone" "iphone"
run_family "iPad" "ipad"
