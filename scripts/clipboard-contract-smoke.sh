#!/bin/bash
set -euo pipefail

SERVICES="iOS/DesktopServices.swift"
UI="iOS/DesktopUtilityCenter.swift"
ROUTING="iOS/Desktop/Apps/DesktopClipboardRouting.swift"
HITS="iOS/Desktop/Apps/DesktopClipboardHitRegistry.swift"
SESSION="iOS/Desktop/DesktopSessionExtensions.swift"
POINTER_SMOKE="iOS/Desktop/Debug/DesktopClipboardPointerSmoke.swift"
WEBVIEW_SMOKE="iOS/Desktop/Debug/DesktopClipboardWebViewSmoke.swift"
IPHONE_SMOKE="scripts/clipboard-simulator-smoke.sh"
IPAD_SMOKE="scripts/ipad-layout-smoke.sh"

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq -- "$pattern" "$file"; then
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
require '.desktopClipboardHitTarget(.toolbarRefresh' "$UI" 'Refresh must expose rendered pointer geometry'
require '.desktopClipboardHitTarget(.toolbarClear' "$UI" 'Clear must expose rendered pointer geometry'
require 'Button("Paste", systemImage: "arrow.down.doc")' "$UI" 'Paste control missing'
require 'desktop.pasteClipboardItemIntoPreviousApp(item)' "$UI" 'Paste must use explicit previous-app ownership routing'
require '.disabled(!desktop.canPasteClipboardIntoPreviousApp)' "$UI" 'Paste must disable when the immediate prior window is not an editable target'
require '.desktopClipboardHitTarget(.itemPaste(item)' "$UI" 'Paste must expose rendered pointer geometry'
require 'Button("Copy", systemImage: "doc.on.doc")' "$UI" 'Copy control missing'
require '.desktopClipboardHitTarget(.itemCopy(item)' "$UI" 'Copy must expose rendered pointer geometry'
require 'Button("Notes", systemImage: "note.text.badge.plus")' "$UI" 'Notes handoff missing'
require 'DesktopClipboardHitRegistry.shared.perform(.itemNotes(item), desktop: desktop)' "$UI" 'touch Notes handoff must reuse the authoritative rendered-pointer Notes route'
require '.desktopClipboardHitTarget(.itemNotes(item)' "$UI" 'Notes handoff must expose rendered pointer geometry'
require 'ShareLink(item: item)' "$UI" 'Share control missing'
require '.desktopClipboardHitTarget(.itemShare(item)' "$UI" 'Share must expose rendered pointer geometry'
require 'DesktopNativeScrollBridge(key: "Clipboard")' "$UI" 'Clipboard history must register a native two-axis scroll surface'
require 'Clear iOS Clipboard & Kamihi History' "$UI" 'destructive clear confirmation missing'
require 'Clipboard history is not written to disk.' "$UI" 'memory-only privacy disclosure missing'

require 'guard activeWindow?.title == "Clipboard"' "$ROUTING" 'Clipboard must be frontmost before resolving a paste destination'
require 'let previousVisible = windows[..<clipboardIndex].reversed().first { !$0.isMinimized }' "$ROUTING" 'Paste destination must be the immediately previous visible window'
require 'Self.clipboardPasteTargetTitles.contains(previousVisible.title)' "$ROUTING" 'Unsupported prior windows must disable paste instead of being skipped'
require 'restoreAndActivate(destination.id)' "$ROUTING" 'Paste must transfer focus to the intended destination before insertion'
require 'typeIntoActiveDesktopField(text)' "$ROUTING" 'Paste must reuse the normal app-specific typing pipeline'

require 'if window.title == "Clipboard"' "$SESSION" 'frontmost Clipboard clicks must route through the native hit registry'
require 'handleClipboardClick(at: cursor, in: frame)' "$SESSION" 'Clipboard click routing implementation missing'
require 'window.title != "Clipboard"' "$SESSION" 'Clipboard secondary clicks must not fall through into WebKit'
require 'final class DesktopClipboardHitRegistry' "$HITS" 'Clipboard rendered hit registry missing'
require 'func handleClipboardClick(at point: CGPoint, in frame: CGRect)' "$HITS" 'Clipboard pointer resolver missing'
require '(!clipboard.items.isEmpty || !UIPasteboard.general.items.isEmpty)' "$HITS" 'software-pointer Clear must respect the disabled state'
require 'UIActivityViewController(activityItems: [text]' "$HITS" 'software-pointer Share must use the public system activity controller'
require '$0.activationState == .foregroundActive && $0.screen === UIScreen.main' "$HITS" 'Share must target the interactive main-screen scene rather than the passive external display'

require 'KAMIHI_CLIPBOARD_WEBVIEW_OK' "$WEBVIEW_SMOKE" 'WebView handoff smoke success marker missing'
require 'WKWebViewConfiguration()' "$WEBVIEW_SMOKE" 'WebView handoff smoke must use a real local WKWebView'
require 'configuration.websiteDataStore = .nonPersistent()' "$WEBVIEW_SMOKE" 'WebView fixture must not persist website data'
require 'DesktopWebInputRegistry.shared.register(webView, key: "Browser")' "$WEBVIEW_SMOKE" 'WebView fixture must use the production Browser input registry'
require 'desktop.clipboardPasteDestination?.id == browserID' "$WEBVIEW_SMOKE" 'WebView smoke must prove immediate-adjacent Browser ownership'
require 'desktop.pasteClipboardItemIntoPreviousApp(payload)' "$WEBVIEW_SMOKE" 'WebView smoke must exercise the production Clipboard paste route'
require 'VALUE:\(payload)' "$WEBVIEW_SMOKE" 'WebView smoke must require exactly one editor insertion'

require 'KAMIHI_CLIPBOARD_POINTER_OK' "$POINTER_SMOKE" 'rendered pointer smoke success marker missing'
require 'desktop.clickAtCursor()' "$POINTER_SMOKE" 'rendered pointer smoke must exercise the production software-pointer path'
require '.toolbarRefresh' "$POINTER_SMOKE" 'pointer smoke must exercise Refresh'
require '.itemCopy(refreshed)' "$POINTER_SMOKE" 'pointer smoke must exercise Copy'
require '.itemNotes(refreshed)' "$POINTER_SMOKE" 'pointer smoke must exercise Notes handoff'
require '.itemPaste(refreshed)' "$POINTER_SMOKE" 'pointer smoke must exercise Paste'
require '.itemShare(refreshed)' "$POINTER_SMOKE" 'pointer smoke must exercise Share'
require '.toolbarClear' "$POINTER_SMOKE" 'pointer smoke must exercise Clear confirmation'
require 'DesktopNativeScrollRegistry.shared.scroll(key: "Clipboard"' "$POINTER_SMOKE" 'pointer smoke must exercise long-history native scrolling'

require '-KamihiClipboardLifecycleSmoke' "$IPHONE_SMOKE" 'iPhone smoke must launch the Clipboard harness'
require 'KAMIHI_CLIPBOARD_LIFECYCLE_OK' "$IPHONE_SMOKE" 'iPhone smoke must require the lifecycle marker'
require 'KAMIHI_CLIPBOARD_WEBVIEW_OK' "$IPHONE_SMOKE" 'iPhone smoke must require the WebView handoff marker'
require 'KAMIHI_CLIPBOARD_POINTER_OK' "$IPHONE_SMOKE" 'iPhone smoke must require the rendered-pointer marker'
require 'clipboard-pointer-controls.png' "$IPHONE_SMOKE" 'iPhone smoke must capture pointer-control visual evidence'

require '-KamihiClipboardLifecycleSmoke' "$IPAD_SMOKE" 'iPad smoke must launch the Clipboard lifecycle harness'
require '"ClipboardSmoke" "KAMIHI_CLIPBOARD_LIFECYCLE_OK"' "$IPAD_SMOKE" 'iPad smoke must require the Clipboard lifecycle success marker'
require '"ClipboardWebViewSmoke" "KAMIHI_CLIPBOARD_WEBVIEW_OK"' "$IPAD_SMOKE" 'iPad smoke must require the Clipboard WebView handoff marker'
require '"ClipboardPointerSmoke" "KAMIHI_CLIPBOARD_POINTER_OK"' "$IPAD_SMOKE" 'iPad smoke must require the rendered Clipboard pointer success marker'
require 'ipad-clipboard-pointer-controls.png' "$IPAD_SMOKE" 'iPad smoke must capture rendered Clipboard visual evidence'
require 'KAMIHI_IPAD_CLIPBOARD_LIFECYCLE_OK' "$IPAD_SMOKE" 'iPad Clipboard lifecycle success artifact missing'
require 'KAMIHI_IPAD_CLIPBOARD_WEBVIEW_OK' "$IPAD_SMOKE" 'iPad Clipboard WebView success artifact missing'
require 'KAMIHI_IPAD_CLIPBOARD_POINTER_OK' "$IPAD_SMOKE" 'iPad Clipboard pointer success artifact missing'

if grep -Fq 'desktop.typeIntoActiveDesktopField(item)' "$UI"; then
  echo 'Clipboard contract failed: Paste must never type while Clipboard owns active-window focus' >&2
  exit 1
fi

if grep -Fq 'notes.text' "$UI"; then
  echo 'Clipboard contract failed: touch Notes handoff must not mutate the compatibility text mirror directly' >&2
  exit 1
fi

if grep -Fq 'UserDefaults' "$SERVICES" && awk '/final class DesktopClipboardStore/{flag=1} flag{print} /final class DesktopFocusTimer/{flag=0}' "$SERVICES" | grep -Fq 'UserDefaults'; then
  echo 'Clipboard contract failed: clipboard history must remain memory-only' >&2
  exit 1
fi

echo 'Clipboard contract OK'
