#!/bin/bash
set -euo pipefail

SERVICES="iOS/DesktopServices.swift"
UI="iOS/DesktopUtilityCenter.swift"
ROUTING="iOS/Desktop/Apps/DesktopClipboardRouting.swift"

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
require 'Button("Paste", systemImage: "arrow.down.doc")' "$UI" 'Paste control missing'
require 'desktop.pasteClipboardItemIntoPreviousApp(item)' "$UI" 'Paste must use explicit previous-app ownership routing'
require '.disabled(!desktop.canPasteClipboardIntoPreviousApp)' "$UI" 'Paste must disable when the immediate prior window is not an editable target'
require 'Button("Copy", systemImage: "doc.on.doc")' "$UI" 'Copy control missing'
require 'Button("Notes", systemImage: "note.text.badge.plus")' "$UI" 'Notes handoff missing'
require 'ShareLink(item: item)' "$UI" 'Share control missing'
require 'Clear iOS Clipboard & Kamihi History' "$UI" 'destructive clear confirmation missing'
require 'Clipboard history is not written to disk.' "$UI" 'memory-only privacy disclosure missing'

require 'guard activeWindow?.title == "Clipboard"' "$ROUTING" 'Clipboard must be frontmost before resolving a paste destination'
require 'let previousVisible = windows[..<clipboardIndex].reversed().first { !$0.isMinimized }' "$ROUTING" 'Paste destination must be the immediately previous visible window'
require 'Self.clipboardPasteTargetTitles.contains(previousVisible.title)' "$ROUTING" 'Unsupported prior windows must disable paste instead of being skipped'
require 'restoreAndActivate(destination.id)' "$ROUTING" 'Paste must transfer focus to the intended destination before insertion'
require 'typeIntoActiveDesktopField(text)' "$ROUTING" 'Paste must reuse the normal app-specific typing pipeline'

if grep -Fq 'desktop.typeIntoActiveDesktopField(item)' "$UI"; then
  echo 'Clipboard contract failed: Paste must never type while Clipboard owns active-window focus' >&2
  exit 1
fi

if grep -Fq 'UserDefaults' "$SERVICES" && awk '/final class DesktopClipboardStore/{flag=1} flag{print} /final class DesktopFocusTimer/{flag=0}' "$SERVICES" | grep -Fq 'UserDefaults'; then
  echo 'Clipboard contract failed: clipboard history must remain memory-only' >&2
  exit 1
fi

echo 'Clipboard contract OK'
