#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEBVIEW="$ROOT_DIR/iOS/Desktop/Apps/Browser/WKWebViewRepresentable.swift"
CHATGPT="$ROOT_DIR/iOS/Desktop/Apps/ChatGPT/DesktopChatGPTView.swift"
YOUTUBE="$ROOT_DIR/iOS/Desktop/Apps/YouTube/DesktopYouTubeView.swift"

require_literal() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Missing standalone web-app contract: $label"
    exit 1
  fi
}

for file in "$WEBVIEW" "$CHATGPT" "$YOUTUBE"; do
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

echo 'Standalone web-app contract OK'
