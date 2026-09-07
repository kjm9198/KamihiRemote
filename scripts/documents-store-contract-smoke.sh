#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="$ROOT/iOS/Desktop/Apps/Documents/DesktopDocumentsStore.swift"

fail() {
  echo "documents-store-contract: FAIL: $*" >&2
  exit 1
}

[[ -f "$STORE" ]] || fail "DesktopDocumentsStore.swift is missing"

python3 - "$STORE" <<'PY' || fail "Documents persistence/lifecycle contract is broken"
import sys

text = open(sys.argv[1], encoding="utf-8").read()
required = [
    'private let activeDocumentStorageKey = "kamihi.desktop.documents.v1.active"',
    'private var isRestoring = false',
    'let hadPersistedCollection = loadDocuments()',
    'restoreActiveSelection()',
    'seedInitialDocument()',
    'private func saveDocuments()',
    'private func saveActiveSelection()',
    'private func loadDocuments() -> Bool',
    'documents = saved',
    'return true',
    'guard !documents.isEmpty else {',
    'self.activeDocumentID = nil',
    'let fallbackIndex = min(removedIndex, documents.count - 1)',
]
for needle in required:
    if needle not in text:
        raise SystemExit(f"missing Documents lifecycle guard: {needle}")

if 'if documents.isEmpty {\n            let replacement = Document(title: "Untitled Document")' in text:
    raise SystemExit("delete-all still recreates a document instead of preserving the empty state")

# Restoring the document collection must not invoke a combined save routine that
# deletes the active ID before it has been read back from UserDefaults.
if 'didSet { save() }' in text:
    raise SystemExit("combined didSet save can still erase active selection during restore")
PY

echo "documents-store-contract: PASS"
