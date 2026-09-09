#!/usr/bin/env bash
set -euo pipefail

DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
BUNDLE="com.kamihi.remote"
MARKER_NAME="kamihi-chatgpt-lifecycle-smoke.txt"
GENERAL_RESULT="$SMOKE_DIR/result.txt"
mkdir -p "$SMOKE_DIR"

[[ -d "$APP" ]] || { echo "ChatGPT smoke requires the simulator build from apple-integration-smoke.sh"; exit 1; }

# Bound CoreSimulator infrastructure only. The ChatGPT lifecycle assertion itself
# still gets exactly one app launch and must emit its own success marker.
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
            boot_rank=0 if device.get("state") == "Booted" else 1
            candidates.append((version, boot_rank, name, device["udid"]))
if not candidates:
    raise SystemExit(1)
latest=max(item[0] for item in candidates)
choices=sorted([item for item in candidates if item[0] == latest], key=lambda item: (item[1], item[2]))
_, _, name, udid=choices[0]
print(f"{udid}|{name}")
' "$family"
}

previous_iphone_selection() {
  [[ -f "$GENERAL_RESULT" ]] || return 1
  local udid name
  udid="$(sed -n 's/^simulator_udid=//p' "$GENERAL_RESULT" | head -1)"
  name="$(sed -n 's/^simulator_name=//p' "$GENERAL_RESULT" | head -1)"
  [[ -n "$udid" && -n "$name" ]] || return 1
  printf '%s|%s\n' "$udid" "$name"
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

has_installed_app() {
  local udid="$1"
  bounded 6 xcrun simctl get_app_container "$udid" "$BUNDLE" app >/dev/null 2>&1
}

ensure_simulator_ready() {
  local udid="$1"
  local name="$2"
  local reuse_installed="${3:-false}"
  local attempt

  # The preceding general Desktop smoke has already booted a simulator and
  # installed this exact current-SHA app. Reuse it instead of throwing away a
  # known-good CoreSimulator and starting migration on a fresh iPhone.
  if [[ "$reuse_installed" == "true" ]] && is_booted "$udid" && has_installed_app "$udid"; then
    bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
    echo "Reusing exact-build simulator from general Desktop smoke: $name ($udid)"
    return 0
  fi

  if ! is_booted "$udid"; then
    bounded 8 xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    # Booted alone is not sufficient on fresh hosted-runner devices: installation
    # services can remain unavailable while first-boot migrations run. Wait for
    # CoreSimulator terminal readiness, but keep the infrastructure wait bounded.
    bounded 150 xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  fi

  attempt=1
  while (( attempt <= 30 )); do
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
  while (( attempt <= 4 )); do
    if bounded 15 xcrun simctl install "$udid" "$APP" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "Simulator reached Booted state but never accepted exact-build app install: $name ($udid)"
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
  local selection udid name poll data_container marker_file evidence_log reuse_installed=false

  if [[ "$family" == "iPhone" ]] && selection="$(previous_iphone_selection)"; then
    reuse_installed=true
  else
    selection="$(pick_device "$family")"
  fi

  udid="${selection%%|*}"
  name="${selection#*|}"
  evidence_log="$SMOKE_DIR/chatgpt-lifecycle-${slug}.log"
  : > "$evidence_log"
  echo "==> ChatGPT lifecycle smoke on $name ($udid)"

  if ! ensure_simulator_ready "$udid" "$name" "$reuse_installed"; then
    capture_evidence "$udid" "$slug"
    return 1
  fi

  data_container="$(bounded 8 xcrun simctl get_app_container "$udid" "$BUNDLE" data 2>/dev/null || true)"
  if [[ -z "$data_container" || ! -d "$data_container" ]]; then
    echo "Could not resolve ChatGPT smoke app container on $name"
    capture_evidence "$udid" "$slug"
    return 1
  fi

  marker_file="$data_container/tmp/$MARKER_NAME"
  rm -f "$marker_file"

  if ! bounded 10 xcrun simctl launch \
      --terminate-running-process \
      "$udid" "$BUNDLE" -KamihiDesktopLab -KamihiChatGPTLifecycleSmoke >/dev/null; then
    echo "ChatGPT lifecycle app launch failed on $name"
    capture_evidence "$udid" "$slug"
    return 1
  fi

  poll=1
  while (( poll <= 30 )); do
    if [[ -f "$marker_file" ]]; then
      cat "$marker_file" | tee "$evidence_log"

      if grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_OK" "$marker_file"; then
        capture_evidence "$udid" "$slug"
        echo "KAMIHI_CHATGPT_LIFECYCLE_OK ($name)"
        bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
        return 0
      fi

      if grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_FAIL" "$marker_file"; then
        echo "ChatGPT lifecycle harness reported failure on $name"
        capture_evidence "$udid" "$slug"
        bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
        return 1
      fi
    fi

    sleep 1
    poll=$((poll + 1))
  done

  echo "ChatGPT lifecycle success marker was not observed on $name"
  if [[ -f "$marker_file" ]]; then
    cat "$marker_file" | tee "$evidence_log"
  fi
  capture_evidence "$udid" "$slug"
  bounded 5 xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
  return 1
}

run_family "iPhone" "iphone"
run_family "iPad" "ipad"
