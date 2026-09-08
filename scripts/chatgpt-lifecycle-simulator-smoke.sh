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
  xcrun simctl list devices available -j | python3 - "$family" <<'PY'
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
PY
}

run_family() {
  local family="$1"
  local slug="$2"
  local selection udid name poll
  selection="$(pick_device "$family")"
  udid="${selection%%|*}"
  name="${selection#*|}"
  echo "==> ChatGPT lifecycle smoke on $name ($udid)"

  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" "$BUNDLE" -KamihiDesktopLab -KamihiChatGPTLifecycleSmoke >/dev/null

  poll=1
  while (( poll <= 12 )); do
    if xcrun simctl spawn "$udid" log show --last 1m --style compact \
      --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE_OK"' 2>/dev/null \
      | grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_OK"; then
      xcrun simctl io "$udid" screenshot "$SMOKE_DIR/chatgpt-lifecycle-${slug}.png" >/dev/null
      xcrun simctl spawn "$udid" log show --last 2m --style compact \
        --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE"' \
        > "$SMOKE_DIR/chatgpt-lifecycle-${slug}.log" 2>/dev/null || true
      echo "KAMIHI_CHATGPT_LIFECYCLE_OK ($name)"
      xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
      return 0
    fi

    if xcrun simctl spawn "$udid" log show --last 1m --style compact \
      --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CHATGPT_LIFECYCLE_FAIL"' 2>/dev/null \
      | grep -Fq "KAMIHI_CHATGPT_LIFECYCLE_FAIL"; then
      echo "ChatGPT lifecycle harness reported failure on $name"
      return 1
    fi

    sleep 1
    poll=$((poll + 1))
  done

  echo "ChatGPT lifecycle success marker was not observed on $name"
  return 1
}

run_family "iPhone" "iphone"
run_family "iPad" "ipad"
