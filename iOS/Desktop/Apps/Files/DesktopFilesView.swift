import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import PDFKit

/// Kamihi's file manager counterpart: an edge-to-edge Finder-like sidebar with a
/// compact toolbar and native PDFKit/Quick Look preview. Imported files remain
/// private copies in the app sandbox unless the user explicitly shares them.
struct DesktopFilesView: View {
    @State private var importedFiles: [URL] = DesktopDocumentLibrary.load()
    @State private var showDocumentPicker = false
    @State private var selectedFile: URL?
    @State private var searchText = ""
    @State private var importErrorMessage: String?

    private var visibleFiles: [URL] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return importedFiles }
        return importedFiles.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: DesktopShellMetrics.sidebarWidth)
            previewPane
        }
        .background(DesktopShellPalette.canvas)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { pickedFiles in
                let result = DesktopDocumentLibrary.importCopies(from: pickedFiles)
                importedFiles = DesktopDocumentLibrary.load()
                if let first = result.imported.first {
                    selectedFile = first
                } else if selectedFile == nil {
                    selectedFile = importedFiles.first
                }
                importErrorMessage = result.failureMessage
            }
        }
        .alert("Couldn’t Import Some Files", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "The selected files could not be imported.")
        }
        .onAppear {
            importedFiles = DesktopDocumentLibrary.load()
            if let selectedFile, !importedFiles.contains(selectedFile) {
                self.selectedFile = importedFiles.first
            } else if selectedFile == nil {
                selectedFile = importedFiles.first
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { showDocumentPicker = true } label: {
                    DesktopToolbarIconLabel("plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import files")
            }
            .padding(.horizontal, 10)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(8)

            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .foregroundStyle(.blue)
                    .frame(width: 18)
                Text("On My iPhone")
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)

            if visibleFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "doc.badge.plus" : "magnifyingglass")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No Files" : "No Results")
                        .font(.system(size: 12, weight: .semibold))
                    if searchText.isEmpty {
                        Button("Import Files") { showDocumentPicker = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(visibleFiles, id: \.self) { file in
                            fileRow(file)
                        }
                    }
                    .background(DesktopNativeScrollBridge(key: "Files"))
                    .padding(7)
                }
            }

            HStack {
                Text("\(importedFiles.count) item\(importedFiles.count == 1 ? "" : "s")")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
        }
        .desktopSidebarSurface()
    }

    private func fileRow(_ file: URL) -> some View {
        let selected = selectedFile == file
        return Button {
            selectedFile = file
        } label: {
            HStack(spacing: 8) {
                Image(systemName: fileIcon(for: file))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fileTint(for: file))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(fileDetail(for: file))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 42)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: file) { Label("Share or Export", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) { remove(file) } label: { Label("Remove", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        if let file = selectedFile {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: fileIcon(for: file))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(fileTint(for: file))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(file.lastPathComponent)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                        Text(fileDetail(for: file))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShareLink(item: file) {
                        DesktopToolbarIconLabel("square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share file")
                    Button { showDocumentPicker = true } label: {
                        DesktopToolbarIconLabel("plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Import another file")
                }
                .padding(.horizontal, 11)
                .frame(height: DesktopShellMetrics.toolbarHeight)
                .desktopAppToolbar()

                NativeFilePreview(url: file)
                    .id(file)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesktopShellPalette.canvas)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Select a file to preview")
                    .font(.system(size: 14, weight: .semibold))
                Text("PDFs use PDFKit. Images, Office/iWork files and supported formats use Quick Look.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button("Import Files") { showDocumentPicker = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesktopShellPalette.canvas)
        }
    }

    private func remove(_ file: URL) {
        DesktopDocumentLibrary.remove(file)
        importedFiles = DesktopDocumentLibrary.load()
        if selectedFile == file { selectedFile = importedFiles.first }
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
        case "numbers", "xls", "xlsx": return .green
        default: return .accentColor
        }
    }

    private func fileDetail(for url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "Document" : url.pathExtension.uppercased()
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
            return "\(ext) · \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))"
        }
        return ext
    }
}

private enum DesktopDocumentLibrary {
    private static let folderName = "Kamihi Desktop Files"

    struct ImportResult {
        let imported: [URL]
        let failedNames: [String]

        var failureMessage: String? {
            guard !failedNames.isEmpty else { return nil }
            if failedNames.count == 1 {
                return "\(failedNames[0]) couldn’t be copied into Kamihi Files. The original file was not changed."
            }
            return "\(failedNames.count) files couldn’t be copied into Kamihi Files. The original files were not changed."
        }
    }

    static func load() -> [URL] {
        guard let directory = directory(createIfNeeded: true),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    static func importCopies(from urls: [URL]) -> ImportResult {
        guard let directory = directory(createIfNeeded: true) else {
            return ImportResult(imported: [], failedNames: urls.map(\.lastPathComponent))
        }

        var imported: [URL] = []
        var failedNames: [String] = []
        for source in urls {
            let destination = uniqueDestination(for: source.lastPathComponent, in: directory)
            let didAccessSecurityScope = source.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScope {
                    source.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                imported.append(destination)
            } catch {
                failedNames.append(source.lastPathComponent)
            }
        }
        return ImportResult(imported: imported, failedNames: failedNames)
    }

    static func remove(_ url: URL) {
        guard let directory = directory(createIfNeeded: false),
              url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func directory(createIfNeeded: Bool) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        if createIfNeeded && !FileManager.default.fileExists(atPath: directory.path) {
            do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            catch { return nil }
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

private struct NativeFilePreview: View {
    let url: URL
    var body: some View {
        if url.pathExtension.lowercased() == "pdf" { NativePDFPreview(url: url) }
        else { QuickLookPreview(url: url) }
    }
}

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
        registerScrollableDescendant(of: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        registerScrollableDescendant(of: view)
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
        view.autoScales = true
    }

    static func dismantleUIView(_ view: PDFView, coordinator: ()) {
        if let scrollView = firstScrollView(in: view) {
            DesktopNativeScrollRegistry.shared.unregister(scrollView, key: "Files")
        }
    }

    private func registerScrollableDescendant(of view: UIView) {
        DispatchQueue.main.async {
            guard let scrollView = Self.firstScrollView(in: view) else { return }
            DesktopNativeScrollRegistry.shared.register(scrollView, key: "Files")
        }
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) { return scrollView }
        }
        return nil
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        DispatchQueue.main.async {
            guard let scrollView = Self.firstScrollView(in: controller.view) else { return }
            DesktopNativeScrollRegistry.shared.register(scrollView, key: "Files")
        }
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = Self.firstScrollView(in: controller.view) else { return }
            DesktopNativeScrollRegistry.shared.register(scrollView, key: "Files")
        }
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
        controller.currentPreviewItemIndex = 0
    }

    static func dismantleUIViewController(_ controller: QLPreviewController, coordinator: Coordinator) {
        if let scrollView = firstScrollView(in: controller.view) {
            DesktopNativeScrollRegistry.shared.unregister(scrollView, key: "Files")
        }
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) { return scrollView }
        }
        return nil
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

private struct DocumentPicker: UIViewControllerRepresentable {
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { parent.onPicked(urls) }
    }
}
