#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORE="$ROOT/iOS/Desktop/Apps/Photos/DesktopPhotosStore.swift"

fail() {
  echo "Photos permission recovery contract failed: $*" >&2
  exit 1
}

[[ -f "$STORE" ]] || fail "DesktopPhotosStore.swift is missing"

python3 - "$STORE" <<'PY' || fail "foreground permission refresh contract is broken"
import sys

store = open(sys.argv[1], encoding="utf-8").read()
required = [
    "UIApplication.didBecomeActiveNotification",
    "func refreshAuthorizationStatus()",
    "PHPhotoLibrary.authorizationStatus(for: .readWrite)",
    "authorizationStatus = current",
    "reloadGrantedAssets()",
]
for needle in required:
    if needle not in store:
        raise SystemExit(f"missing Photos recovery guard: {needle}")

observer_index = store.find("UIApplication.didBecomeActiveNotification")
refresh_call_index = store.find("self?.refreshAuthorizationStatus()", observer_index)
if observer_index < 0 or refresh_call_index < observer_index:
    raise SystemExit("foreground activation does not refresh Photos authorization")

refresh_index = store.find("public func refreshAuthorizationStatus()")
status_index = store.find("authorizationStatus = current", refresh_index)
reload_index = store.find("reloadGrantedAssets()", status_index)
if refresh_index < 0 or status_index < refresh_index or reload_index < status_index:
    raise SystemExit("Photos refresh must update authorization before reloading assets")
PY

echo "Photos permission recovery contract smoke passed"
