#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEBVIEW="$ROOT_DIR/iOS/Desktop/Apps/Browser/WKWebViewRepresentable.swift"
CHATGPT="$ROOT_DIR/iOS/Desktop/Apps/ChatGPT/DesktopChatGPTView.swift"
YOUTUBE="$ROOT_DIR/iOS/Desktop/Apps/YouTube/DesktopYouTubeView.swift"
HARDWARE_KEYBOARD="$ROOT_DIR/iOS/Desktop/Controller/DesktopHardwareKeyboardReceiver.swift"
TRACKPAD="$ROOT_DIR/iOS/Desktop/Controller/TrackpadEngine.swift"
SESSION_INPUT="$ROOT_DIR/iOS/Desktop/DesktopSessionExtensions.swift"
CHATGPT_SMOKE="$ROOT_DIR/iOS/Desktop/Debug/DesktopChatGPTLifecycleSmoke.swift"

require_literal() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Missing standalone web-app contract: $label"
    exit 1
  fi
}

for file in "$WEBVIEW" "$CHATGPT" "$YOUTUBE" "$HARDWARE_KEYBOARD" "$TRACKPAD" "$SESSION_INPUT" "$CHATGPT_SMOKE"; do
  [[ -f "$file" ]] || { echo "Missing expected standalone web-app source: $file"; exit 1; }
done

# Authentication/session capability must remain owned by normal iOS/WebKit.
require_literal "$WEBVIEW" 'configuration.websiteDataStore = .default()' 'persistent WebKit website data store'
require_literal "$WEBVIEW" 'configuration.defaultWebpagePreferences.preferredContentMode = .desktop' 'desktop content mode request'
require_literal "$WEBVIEW" 'webView.uiDelegate = context.coordinator' 'WKUIDelegate for popup/auth navigation'
require_literal "$WEBVIEW" 'webView.navigationDelegate = context.coordinator' 'WKNavigationDelegate for recovery'
require_literal "$WEBVIEW" 'DesktopWebInputRegistry.shared.register(webView, key: registryKey)' 'phone/hardware input registration'
require_literal "$WEBVIEW" 'DesktopWebInputRegistry.shared.unregister(webView)' 'input unregister on close'
require_literal "$WEBVIEW" 'webView.stopLoading()' 'network/media stop on dismantle'
require_literal "$WEBVIEW" 'webViewWebContentProcessDidTerminate' 'WebKit renderer recovery callback'
require_literal "$WEBVIEW" 'guard webView.superview != nil else { return }' 'do not resurrect closed web apps'

# Do not impersonate desktop Safari. Sites need the real WKWebView/iOS UA for
# capability detection; desktop layout is requested independently above.
if grep -Fq -- 'customUserAgent' "$WEBVIEW"; then
  echo 'Standalone web apps must not override WKWebView.customUserAgent'
  exit 1
fi
if grep -Fq -- 'Macintosh; Intel Mac OS X' "$WEBVIEW"; then
  echo 'Standalone web apps must not impersonate macOS Safari'
  exit 1
fi

# Dedicated web apps must keep stable production URLs and registry identities.
require_literal "$CHATGPT" 'URL(string: "https://chatgpt.com")' 'ChatGPT production URL'
require_literal "$CHATGPT" 'registryKey: "ChatGPT"' 'ChatGPT input registry identity'
require_literal "$YOUTUBE" 'registryKey: "YouTube"' 'YouTube input registry identity'

# YouTube must support the interactions expected from a desktop video app. Keep
# native WebKit element fullscreen enabled for direct iPad/touch interaction and
# preserve the software-pointer fullscreen fallback for external-display control.
require_literal "$WEBVIEW" 'configuration.preferences.isElementFullscreenEnabled = true' 'WebKit element fullscreen enabled'
require_literal "$WEBVIEW" 'kamihi-youtube-fullscreen-style' 'software-pointer YouTube fullscreen fallback'
require_literal "$WEBVIEW" 'kamihi-fullscreen-on' 'YouTube fullscreen maximize handoff'
require_literal "$WEBVIEW" '.ytp-fullscreen-button' 'YouTube fullscreen control recognition'

# Root UIScrollView-only routing breaks Shorts and modern SPA feeds. The shared
# web input bridge must route wheel/two-finger deltas into the DOM element under
# the last pointer interaction, walk nested overflow owners, and retain a native
# WKWebView fallback when the page has no matching scroll container.
require_literal "$WEBVIEW" "hit.dispatchEvent(new WheelEvent('wheel'" 'DOM wheel dispatch for nested web apps'
require_literal "$WEBVIEW" 'node.scrollBy({left: dx, top: dy, behavior:' 'nested DOM scroll routing'
require_literal "$WEBVIEW" "'ytd-shorts'" 'YouTube Shorts scroll-owner preference'
require_literal "$WEBVIEW" 'webView.scrollView.setContentOffset(offset, animated: false)' 'native root scroll fallback'

# Resizing must remain discoverable from the phone trackpad without stealing the
# normal two-finger scroll gesture. A one-finger drag can begin resizing only if
# the cursor was already over a visible edge/corner when that gesture began.
require_literal "$TRACKPAD" 'private var oneFingerResizeArmed = false' 'one-finger edge resize intent latch'
require_literal "$TRACKPAD" 'oneFingerResizeArmed = desktop.resizeEdgeAtCursor() != nil' 'resize armed from gesture-start edge'
require_literal "$TRACKPAD" 'if oneFingerResizeArmed,' 'one-finger edge resize branch'
require_literal "$TRACKPAD" 'desktop.beginPointerResize()' 'edge resize uses shared window resize path'
require_literal "$TRACKPAD" 'if state == .scrolling {' 'two-finger scrolling stays committed once started'

# Normal Enter in ChatGPT is a send action even though its composer is
# contenteditable. The app-specific branch must run before the generic multiline
# contenteditable/textarea newline path so phone and hardware keyboards cannot
# silently turn Enter into a line break. Other web editors keep normal multiline
# behavior rather than inheriting ChatGPT-specific semantics.
require_literal "$WEBVIEW" 'let chatGPTSubmitMode = key == "ChatGPT" ? "true" : "false"' 'ChatGPT-only Enter mode'
require_literal "$WEBVIEW" 'if (chatGPTSubmitMode && el.isContentEditable)' 'ChatGPT contenteditable send branch'
require_literal "$WEBVIEW" '[data-testid="send-button"]' 'ChatGPT send button fallback'
require_literal "$WEBVIEW" 'if (el.tagName === '\''TEXTAREA'\'' || el.isContentEditable)' 'generic multiline Enter fallback'
require_literal "$SESSION_INPUT" 'DesktopWebInputRegistry.shared.pressEnter(key: key)' 'DesktopSession Enter routing to WebKit'
require_literal "$HARDWARE_KEYBOARD" 'desktop.pressEnterInActiveDesktopField()' 'hardware keyboard Enter routing'

# The first-attempt iPhone+iPad lifecycle smoke must also exercise a credential-free
# local composer fixture through the same registry operations used in production.
require_literal "$CHATGPT_SMOKE" 'configuration.websiteDataStore = .nonPersistent()' 'credential-free ChatGPT input fixture'
require_literal "$CHATGPT_SMOKE" 'DesktopWebInputRegistry.shared.type(key: "ChatGPT", text: "hello")' 'ChatGPT routed typing smoke'
require_literal "$CHATGPT_SMOKE" 'DesktopWebInputRegistry.shared.deleteBackward(key: "ChatGPT")' 'ChatGPT routed delete smoke'
require_literal "$CHATGPT_SMOKE" 'DesktopWebInputRegistry.shared.pressEnter(key: "ChatGPT")' 'ChatGPT routed Enter smoke'
require_literal "$CHATGPT_SMOKE" 'waitForTitle("SENT:hello"' 'ChatGPT send assertion'

echo 'Standalone web-app contract OK'
