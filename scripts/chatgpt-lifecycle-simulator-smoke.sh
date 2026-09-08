#!/usr/bin/env bash
set -euo pipefail

DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
BUNDLE="com.kamihi.remote"
mkdir -p "$SMOKE_DIR"

[[ -d "$APP" ]] || { echo "ChatGPT smoke requires the simulator build from apple-integration-smoke.sh"; exit 1; }

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

  # `simctl bootstatus -b` can block for many minutes on GitHub's macOS-26
  # runners even after CoreSimulator already reports the device as Booted.
  # Bound readiness by observable state and by a successful install instead.
  if ! is_booted "$udid"; then
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  fi

  attempt=1
  while (( attempt <= 60 )); do
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

  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$BUNDLE" >/dev/null 2>&1 || true

  attempt=1
  while (( attempt <= 45 )); do
    if xcrun simctl install "$udid" "$APP" >/dev/null 2>&1; then
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
  xcrun simctl io "$udid" screenshot "$SMOKE_DIR/chatgpt-lifecycle-${slug}.png" >/dev/null 2>&1 || true
  xcrun simctl spawn "$udid" log show --last 4m --style compact \
    --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE"' \
    > "$SMOKE_DIR/chatgpt-lifecycle-${slug}.log" 2>/dev/null || true
}

run_family() {
  local family="$1"
  local slug="$2"
  local selection udid name poll
  selection="$(pick_device "$family")"
  udid="${selection%%|*}"
  name="${selection#*|}"
  echo "==> ChatGPT lifecycle smoke on $name ($udid)"

  if ! ensure_simulator_ready "$udid" "$name"; then
    capture_evidence "$udid" "$slug"
    return 1
  fi

  if ! xcrun simctl launch "$udid" "$BUNDLE" -KamihiDesktopLab -KamihiChatGPTLifecycleSmoke >/dev/null; then
    echo "ChatGPT lifecycle app launch failed on $name"
    capture_evidence "$udid" "$slug"
    return 1
  fi

  poll=1
  while (( poll <= 20 )); do
    if xcrun simctl spawn "$udid" log show --last 2m --style compact \
      --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE_OK"' 2>/dev/null \
      | grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_OK"; then
      capture_evidence "$udid" "$slug"
      echo "KAMIHI_CHATGPT_LIFECYCLE_OK ($name)"
      xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
      return 0
    fi

    if xcrun simctl spawn "$udid" log show --last 2m --style compact \
      --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE_FAIL"' 2>/dev/null \
      | grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_FAIL"; then
      echo "ChatGPT lifecycle harness reported failure on $name"
      capture_evidence "$udid" "$slug"
      xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
      return 1
    fi

    sleep 1
    poll=$((poll + 1))
  done

  echo "ChatGPT lifecycle success marker was not observed on $name"
  capture_evidence "$udid" "$slug"
  xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  return 1
}

run_family "iPhone" "iphone"
run_family "iPad" "ipad"
