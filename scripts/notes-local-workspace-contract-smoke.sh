#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="$ROOT/iOS/Desktop/Apps/Notes/DesktopNotesStore.swift"
VIEW="$ROOT/iOS/Desktop/Apps/Notes/DesktopNotesView.swift"

fail() {
  echo "notes-local-workspace-contract: FAIL: $*" >&2
  exit 1
}

[[ -f "$STORE" ]] || fail "DesktopNotesStore.swift is missing"
[[ -f "$VIEW" ]] || fail "DesktopNotesView.swift is missing"

python3 - "$STORE" "$VIEW" <<'PY' || fail "local rich Notes workspace contract is broken"
import sys

store = open(sys.argv[1], encoding="utf-8").read()
view = open(sys.argv[2], encoding="utf-8").read()

required_store = [
    'public var richBody: AttributedString?',
    'public func attributedBody(for id: UUID) -> AttributedString',
    'public func updateAttributedBody(_ value: AttributedString, for id: UUID)',
    'note.body = String(value.characters)',
    'private func handleTrailingSlashCommand() -> Bool',
    'case "/todo":',
    'case "/meeting":',
    'case "/project":',
    'case "/daily":',
    'case "/summarize", "/rewrite", "/tasks", "/brainstorm":',
    'let model = SystemLanguageModel.default',
    'guard model.isAvailable else {',
    'let session = LanguageModelSession(',
    'model: model,',
    'let response = try await session.respond(to:',
    'appendLocalAIResult(response.content',
]
required_view = [
    '@State private var richSelection = AttributedTextSelection()',
    'TextEditor(',
    'text: attributedBodyBinding(for: activeID)',
    'selection: $richSelection',
    'Local workspace · /help for blocks & AI',
    'store.localAIStatus',
    'store.isLocalAIWorking',
]

for needle in required_store:
    if needle not in store:
        raise SystemExit(f"missing local Notes store guard: {needle}")
for needle in required_view:
    if needle not in view:
        raise SystemExit(f"missing local Notes view guard: {needle}")

# The Notes AI path must remain explicitly on-device. Do not silently add a
# network/cloud fallback for private note contents.
for banned in [
    'URLSession',
    'PrivateCloudComputeLanguageModel',
    'api.openai.com',
    'api.anthropic.com',
    'Authorization: Bearer',
]:
    if banned in store or banned in view:
        raise SystemExit(f"cloud/network dependency leaked into local Notes: {banned}")

# Existing plain-text notes must stay readable after the rich-text upgrade.
if 'public var richBody: AttributedString?' not in store:
    raise SystemExit("rich body is not optional; older notes may fail to decode")
if 'return note.richBody ?? AttributedString(note.body)' not in store:
    raise SystemExit("plain-text Notes migration fallback is missing")
PY

echo "notes-local-workspace-contract: PASS"
