import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import PDFKit

/// Native document and media manager for Kamihi Desktop.
///
/// The iPhone system document picker is deliberately configured with `asCopy: true`.
/// Selected files are then moved into a Kamihi-owned Application Support folder so
/// they remain available after reconnect/relaunch without retaining broad external
/// filesystem access or security-scoped bookmarks.
struct DesktopFilesView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var importedFiles: [URL] = DesktopDocumentLibrary.load()
    @State private var showDocumentPicker = false
    @State private var selectedFile: URL?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)

            Divider()

            previewPane
        }
        .background(canvasBackground)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { pickedFiles in
                let imported = DesktopDocumentLibrary.importCopies(from: pickedFiles)
                importedFiles = DesktopDocumentLibrary.load()
                if let first = imported.first {
                    selectedFile = first
                } else if selectedFile == nil {
                    selectedFile = importedFiles.first
                }
            }
        }
        .onAppear {
            importedFiles = DesktopDocumentLibrary.load()
            if let selectedFile, !importedFiles.contains(selectedFile) {
                self.selectedFile = importedFiles.first
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label("Files", systemImage: "folder.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showDocumentPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(.thinMaterial, in: Circle())
                .accessibilityLabel("Import files")
                .accessibilityHint("Opens the iPhone document picker")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()

            if importedFiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)

                    Text("No Files Added")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Import documents from Files to keep a private copy available on your desktop.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Import Files") {
                        showDocumentPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedFile) {
                    ForEach(importedFiles, id: \.self) { file in
                        HStack(spacing: 9) {
                            Image(systemName: fileIcon(for: file))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(fileTint(for: file))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.deletingPathExtension().lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(fileDetail(for: file))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                        .tag(file)
                        .contextMenu {
                            Button(role: .destructive) {
                                remove(file)
                            } label: {
                                Label("Remove from Files", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: remove)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var previewPane: some View {
        if let file = selectedFile {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: fileIcon(for: file))
                        .foregroundStyle(fileTint(for: file))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.lastPathComponent)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(fileDetail(for: file))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if file.pathExtension.lowercased() == "pdf" {
                        Label("PDF", systemImage: "doc.richtext")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                    }

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                NativeFilePreview(url: file)
                    .id(file)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(canvasBackground)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.secondary)

                Text("Select a file to preview")
                    .font(.system(size: 13, weight: .semibold))

                Text("PDFs use the native PDFKit viewer. Images, Office/iWork files and supported text formats use Quick Look.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(canvasBackground)
        }
    }

    private var sidebarBackground: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white.opacity(0.055))
            : AnyShapeStyle(Color.black.opacity(0.035))
    }

    private var canvasBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.06, blue: 0.075)
            : Color(uiColor: .systemBackground)
    }

    private func remove(_ file: URL) {
        DesktopDocumentLibrary.remove(file)
        importedFiles = DesktopDocumentLibrary.load()
        if selectedFile == file {
            selectedFile = importedFiles.first
        }
    }

    private func remove(at offsets: IndexSet) {
        let removed = offsets.compactMap { index in
            importedFiles.indices.contains(index) ? importedFiles[index] : nil
        }
        removed.forEach(DesktopDocumentLibrary.remove)
        importedFiles = DesktopDocumentLibrary.load()
        if let selectedFile, removed.contains(selectedFile) {
            self.selectedFile = importedFiles.first
        }
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext.fill"
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp": return "photo.fill"
        case "txt", "md", "swift", "json", "js", "ts", "html", "css", "xml", "csv": return "doc.plaintext.fill"
        case "pages", "doc", "docx", "rtf": return "doc.text.fill"
        case "key", "ppt", "pptx": return "rectangle.on.rectangle.angled"
        case "numbers", "xls", "xlsx": return "tablecells.fill"
        default: return "doc.fill"
        }
    }

    private func fileTint(for url: URL) -> Color {
        switch url.pathExtension.lowercased() {
        case "pdf": return .red
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp": return .blue
        case "txt", "md", "swift", "json", "js", "ts", "html", "css", "xml", "csv": return .teal
        default: return .accentColor
        }
    }

    private func fileDetail(for url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "Document" : url.pathExtension.uppercased()
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            return "\(ext) · \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))"
        }
        return ext
    }
}

// MARK: - Persistent sandbox document library

enum DesktopDocumentLibrary {
    private static let folderName = "Kamihi Desktop Files"

    static func load() -> [URL] {
        guard let directory = directory(createIfNeeded: true),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    static func importCopies(from urls: [URL]) -> [URL] {
        guard let directory = directory(createIfNeeded: true) else { return [] }
        var imported: [URL] = []

        for source in urls {
            let destination = uniqueDestination(for: source.lastPathComponent, in: directory)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                imported.append(destination)
            } catch {
                // The picker already hands Kamihi copies. If a provider returns a URL
                // that cannot be copied, skip it rather than retaining external access.
                continue
            }
        }

        return imported
    }

    static func remove(_ url: URL) {
        guard let directory = directory(createIfNeeded: false),
              url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func directory(createIfNeeded: Bool) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        if createIfNeeded && !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return directory
    }

    private static func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let sourceURL = URL(fileURLWithPath: filename)
        let stem = sourceURL.deletingPathExtension().lastPathComponent.isEmpty ? "Document" : sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var candidate = directory.appendingPathComponent(filename)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
            candidate = directory.appendingPathComponent(nextName)
            suffix += 1
        }
        return candidate
    }
}

// MARK: - Native previews

private struct NativeFilePreview: View {
    let url: URL

    var body: some View {
        if url.pathExtension.lowercased() == "pdf" {
            NativePDFPreview(url: url)
        } else {
            QuickLookPreview(url: url)
        }
    }
}

/// PDFKit is used directly for PDFs so the desktop gets native page rendering,
/// zooming and selection behavior instead of treating PDFs as a generic preview.
private struct NativePDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
        view.autoScales = true
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
        controller.currentPreviewItemIndex = 0
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - Document Picker Representable

private struct DocumentPicker: UIViewControllerRepresentable {
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPicked(urls)
        }
    }
}
