#!/bin/bash
set -euo pipefail

FILES_VIEW="iOS/Desktop/Apps/Files/DesktopFilesView.swift"

fail() {
  echo "Files/PDF contract failed: $1" >&2
  exit 1
}

[[ -f "$FILES_VIEW" ]] || fail "missing DesktopFilesView.swift"

# Files must import through the public document picker in copy mode so Kamihi owns
# a sandboxed copy and never depends on another provider remaining mounted.
grep -Fq 'UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)' "$FILES_VIEW" \
  || fail "document picker must remain copy-based"
grep -Fq 'picker.allowsMultipleSelection = true' "$FILES_VIEW" \
  || fail "multi-file import support disappeared"

# Imported content belongs in Application Support and duplicate names must never
# overwrite an existing Kamihi-owned file.
grep -Fq '.applicationSupportDirectory' "$FILES_VIEW" \
  || fail "Files library no longer uses Application Support"
grep -Fq 'uniqueDestination(for: source.lastPathComponent, in: directory)' "$FILES_VIEW" \
  || fail "imports no longer use collision-safe destinations"
grep -Fq 'while FileManager.default.fileExists(atPath: candidate.path)' "$FILES_VIEW" \
  || fail "duplicate-name guard disappeared"

# Delete must remain sandbox-scoped; never allow an arbitrary URL selected by a
# caller to be removed outside the managed Kamihi Files directory.
grep -Fq 'url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL' "$FILES_VIEW" \
  || fail "managed-directory delete boundary disappeared"

# Core usability controls and empty/search states must remain available.
grep -Fq 'TextField("Search", text: $searchText)' "$FILES_VIEW" \
  || fail "Files search control disappeared"
grep -Fq 'Button("Import Files")' "$FILES_VIEW" \
  || fail "empty-state import action disappeared"
grep -Fq 'ShareLink(item: file)' "$FILES_VIEW" \
  || fail "share/export action disappeared"
grep -Fq 'Button(role: .destructive) { remove(file) }' "$FILES_VIEW" \
  || fail "remove action disappeared"

# PDFs must stay on PDFKit continuous vertical scrolling; other supported files
# use Quick Look. Both preview paths must register their real UIScrollView with
# Kamihi's native-scroll bridge so phone two-finger and hardware wheel input route
# to the frontmost visible preview instead of manipulating a window behind it.
grep -Fq 'if url.pathExtension.lowercased() == "pdf" { NativePDFPreview(url: url) }' "$FILES_VIEW" \
  || fail "PDF routing disappeared"
grep -Fq 'view.displayMode = .singlePageContinuous' "$FILES_VIEW" \
  || fail "PDF continuous-page mode disappeared"
grep -Fq 'view.displayDirection = .vertical' "$FILES_VIEW" \
  || fail "PDF vertical scrolling disappeared"
grep -Fq 'DesktopNativeScrollRegistry.shared.register(scrollView, key: "Files")' "$FILES_VIEW" \
  || fail "native scroll registration disappeared"
grep -Fq 'DesktopNativeScrollRegistry.shared.unregister(scrollView, key: "Files")' "$FILES_VIEW" \
  || fail "native scroll cleanup disappeared"
grep -Fq 'QLPreviewController()' "$FILES_VIEW" \
  || fail "Quick Look preview disappeared"

# Reopen must recover from a stale selected URL instead of leaving an unusable
# blank preview after a file was removed between launches.
grep -Fq 'if let selectedFile, !importedFiles.contains(selectedFile)' "$FILES_VIEW" \
  || fail "stale selection recovery disappeared"

echo "Files/PDF contract smoke passed."
