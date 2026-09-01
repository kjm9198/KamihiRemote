import SwiftUI
import UniformTypeIdentifiers
import QuickLook

/// Native document and media manager for Kamihi Desktop.
/// Imported documents stay inside the app sandbox because the system document
/// picker is configured with `asCopy: true`; Files never needs broad filesystem
/// access or a custom credential/storage layer.
struct DesktopFilesView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var importedFiles: [URL] = []
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
            DocumentPicker(selectedFiles: $importedFiles) { pickedFiles in
                if selectedFile == nil {
                    selectedFile = pickedFiles.first
                }
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

                    Text("Import documents from Files to preview them on your desktop.")
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

                Text("PDFs, images, text documents and other Quick Look formats open directly here.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
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
        importedFiles.removeAll { $0 == file }
        if selectedFile == file {
            selectedFile = importedFiles.first
        }
    }

    private func remove(at offsets: IndexSet) {
        let removed = offsets.compactMap { index in
            importedFiles.indices.contains(index) ? importedFiles[index] : nil
        }
        importedFiles.remove(atOffsets: offsets)
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

/// Embeds Apple's native Quick Look renderer directly inside the desktop window.
/// This gives PDFs, images, Office/iWork documents and supported text formats a
/// real preview without copying their contents into Kamihi-owned data models.
private struct NativeFilePreview: UIViewControllerRepresentable {
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
    @Binding var selectedFiles: [URL]
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
            let unique = urls.filter { !parent.selectedFiles.contains($0) }
            parent.selectedFiles.append(contentsOf: unique)
            parent.onPicked(unique)
        }
    }
}
