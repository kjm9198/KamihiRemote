#!/bin/bash
set -euo pipefail

DERIVED_IOS="${RUNNER_TEMP:-/tmp}/kamihi-ios-derived"
SMOKE_DIR="${RUNNER_TEMP:-/tmp}/kamihi-smoke"
APP="$DERIVED_IOS/Build/Products/Debug-iphonesimulator/KamihiRemote.app"
BUNDLE="com.kamihi.remote"
mkdir -p "$SMOKE_DIR"

[[ -d "$APP" ]] || { echo "Clipboard smoke: simulator app missing at $APP"; exit 1; }

SIM_SELECTION="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
payload=json.load(sys.stdin)
preferred=["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro"]
candidates=[]
for runtime, devices in payload.get("devices", {}).items():
    match=re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match: continue
    version=tuple(int(part) for part in match.group(1).split("-"))
    for device in devices:
        name=device.get("name", "")
        if device.get("isAvailable") and name.startswith("iPhone"):
            rank=preferred.index(name) if name in preferred else len(preferred)
            candidates.append((version, rank, name, device["udid"]))
if not candidates: raise SystemExit(1)
latest=max(item[0] for item in candidates)
choices=[item for item in candidates if item[0] == latest]
choices.sort(key=lambda item: (item[1], item[2]))
_, _, name, udid=choices[0]
print(f"{udid}|{name}")
')"
UDID="${SIM_SELECTION%%|*}"
SIM_NAME="${SIM_SELECTION#*|}"

echo "==> Clipboard simulator smoke on $SIM_NAME ($UDID)"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP" >/dev/null 2>&1 || true
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

LOG="$SMOKE_DIR/clipboard-simulator-launch.log"
: > "$LOG"
xcrun simctl launch "$UDID" "$BUNDLE" -KamihiDesktopLab -KamihiClipboardLifecycleSmoke >> "$LOG" 2>&1

poll=1
while (( poll <= 12 )); do
  if xcrun simctl spawn "$UDID" log show --last 1m --style compact \
    --predicate 'subsystem == "com.kamihi.remote" AND composedMessage CONTAINS "KAMIHI_CLIPBOARD_LIFECYCLE_OK"' 2>/dev/null \
    | grep -Fq "KAMIHI_CLIPBOARD_LIFECYCLE_OK"; then
    echo "Clipboard lifecycle runtime marker observed"
    xcrun simctl io "$UDID" screenshot "$SMOKE_DIR/clipboard-lifecycle.png" >/dev/null
    size="$(stat -f '%z' "$SMOKE_DIR/clipboard-lifecycle.png" 2>/dev/null || stat -c '%s' "$SMOKE_DIR/clipboard-lifecycle.png")"
    (( size >= 60000 )) || { echo "Clipboard screenshot too small: $size bytes"; exit 1; }
    echo "KAMIHI_CLIPBOARD_SIMULATOR_SMOKE_OK" | tee "$SMOKE_DIR/clipboard-simulator-smoke.txt"
    exit 0
  fi
  sleep 1
  poll=$((poll + 1))
done

echo "Clipboard lifecycle marker was not observed"
xcrun simctl spawn "$UDID" log show --last 2m --style compact \
  --predicate 'process == "KamihiRemote" OR subsystem == "com.kamihi.remote"' 2>/dev/null \
  | tail -1200 > "$SMOKE_DIR/clipboard-simulator-system.log" || true
exit 1
