#!/bin/bash
set -euo pipefail

SERVICES="iOS/DesktopServices.swift"
UI="iOS/DesktopUtilityCenter.swift"

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq "$pattern" "$file"; then
    echo "Clipboard contract failed: $message" >&2
    exit 1
  fi
}

require 'final class DesktopClipboardStore: ObservableObject' "$SERVICES" 'clipboard store missing'
require 'private var lastChangeCount = -1' "$SERVICES" 'first refresh must not inherit the live pasteboard changeCount'
require 'guard board.changeCount != lastChangeCount else { return }' "$SERVICES" 'change-count deduplication missing'
require 'board.string?.trimmingCharacters(in: .whitespacesAndNewlines)' "$SERVICES" 'clipboard text normalization missing'
require 'items.removeAll { $0 == value }' "$SERVICES" 'duplicate promotion missing'
require 'items.insert(value, at: 0)' "$SERVICES" 'new clipboard value must become most recent'
require 'if items.count > 20 { items.removeLast(items.count - 20) }' "$SERVICES" '20-item memory bound missing'
require 'lastChangeCount = UIPasteboard.general.changeCount' "$SERVICES" 'clear must synchronize pasteboard change state'

require 'Button { clipboard.captureIfChanged() }' "$UI" 'Refresh control missing'
require '.accessibilityLabel("Refresh clipboard")' "$UI" 'Refresh accessibility label missing'
require 'Button("Copy", systemImage: "doc.on.doc")' "$UI" 'Copy control missing'
require 'Button("Notes", systemImage: "note.text.badge.plus")' "$UI" 'Notes handoff missing'
require 'ShareLink(item: item)' "$UI" 'Share control missing'
require 'Clear iOS Clipboard & Kamihi History' "$UI" 'destructive clear confirmation missing'
require 'Clipboard history is not written to disk.' "$UI" 'memory-only privacy disclosure missing'

if grep -Fq 'UserDefaults' "$SERVICES" && awk '/final class DesktopClipboardStore/{flag=1} flag{print} /final class DesktopFocusTimer/{flag=0}' "$SERVICES" | grep -Fq 'UserDefaults'; then
  echo 'Clipboard contract failed: clipboard history must remain memory-only' >&2
  exit 1
fi

echo 'Clipboard contract OK'
