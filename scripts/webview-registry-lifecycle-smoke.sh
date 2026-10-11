#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/iOS/Desktop/Apps/Browser/WKWebViewRepresentable.swift"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Exercise the real registry lifecycle methods using a lightweight WKWebView
# stand-in. This checks identity and click-state semantics without a simulator.
python3 - "$SOURCE" "$TMP/RegistryHarness.swift" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()

def method(name):
    match = re.search(r'\b(?:private\s+)?func\s+' + name + r'\s*\([^)]*\)\s*\{', source)
    if match is None:
        raise SystemExit(f'Missing registry lifecycle method: {name}')
    start = match.start()
    depth = 0
    for pos in range(match.end() - 1, len(source)):
        if source[pos] == '{':
            depth += 1
        elif source[pos] == '}':
            depth -= 1
            if depth == 0:
                return source[start:pos + 1]
    raise SystemExit(f'Unterminated registry lifecycle method: {name}')

harness = r'''import Foundation

final class WKWebView {}
final class Registry {
    private final class WeakWebView {
        weak var value: WKWebView?
        init(_ value: WKWebView) { self.value = value }
    }
    private struct PrimaryClickSample {
        let time: TimeInterval
        let x: CGFloat
        let y: CGFloat
        let count: Int
    }
    private var webViews: [String: WeakWebView] = [:]
    private var lastPrimaryClick: [String: PrimaryClickSample] = [:]
    private var fullscreenMaximizedByKamihi: Set<String> = []

    // These methods are extracted unchanged from the application source.
__METHODS__

    private func seed(_ key: String) {
        lastPrimaryClick[key] = PrimaryClickSample(time: 1, x: 0.5, y: 0.5, count: 1)
    }
    private func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError(message) }
    }
    func run() {
        let original = WKWebView()
        let replacement = WKWebView()
        let other = WKWebView()
        register(original, key: "ChatGPT")
        seed("ChatGPT")
        register(original, key: "ChatGPT")
        check(lastPrimaryClick["ChatGPT"] != nil,
              "Re-registering the same WebView must preserve click sequence")

        register(other, key: "YouTube")
        seed("YouTube")
        register(replacement, key: "ChatGPT")
        check(lastPrimaryClick["ChatGPT"] == nil,
              "Replacement WebView inherited stale double-click history")
        check(lastPrimaryClick["YouTube"] != nil,
              "Replacement cleared another application's click history")

        seed("ChatGPT")
        unregister(original)
        check(webViews["ChatGPT"]?.value === replacement,
              "Late unregister removed replacement WebView")
        check(lastPrimaryClick["ChatGPT"] != nil,
              "Late unregister cleared replacement click history")

        unregister(replacement)
        check(webViews["ChatGPT"] == nil && lastPrimaryClick["ChatGPT"] == nil,
              "Unregister did not clear active WebView state")
        check(webViews["YouTube"]?.value === other,
              "Unregister removed unrelated WebView")
        print("WEBVIEW_REGISTRY_LIFECYCLE_OK")
    }
}
Registry().run()
'''
methods = '\n\n'.join(method(name) for name in ('register', 'unregister', 'pruneReleasedEntries'))
Path(sys.argv[2]).write_text(harness.replace('__METHODS__', methods))
PY

swiftc "$TMP/RegistryHarness.swift" -o "$TMP/registry-harness"
"$TMP/registry-harness"
