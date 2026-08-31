import SwiftUI
import UniformTypeIdentifiers

/// Native document and media manager for Kamihi Desktop.
struct DesktopFilesView: View {
    @State private var importedFiles: [URL] = []
    @State private var showDocumentPicker = false
    @State private var selectedFile: URL?

    var body: some View {
        HStack(spacing: 0) {
            // Files sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Files")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(red: 0.13, green: 0.14, blue: 0.19))

                Divider().background(Color.white.opacity(0.1))

                if importedFiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No Files Added")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(importedFiles, id: \.self) { file in
                            Button {
                                selectedFile = file
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: fileIcon(for: file))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.cyan)

                                    Text(file.lastPathComponent)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(selectedFile == file ? .white : .white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(selectedFile == file ? Color.cyan.opacity(0.2) : Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(width: 140)
            .background(Color(red: 0.10, green: 0.11, blue: 0.15))

            Divider().background(Color.white.opacity(0.1))

            // File Viewer / Preview
            if let file = selectedFile {
                VStack {
                    HStack {
                        Text(file.lastPathComponent)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.19))

                    Spacer()

                    Image(systemName: fileIcon(for: file))
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)

                    Text("File Preview")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(file.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Select a file to preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedFiles: $importedFiles)
        }
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "jpg", "png", "heic": return "photo"
        case "txt", "md", "swift", "json": return "doc.plaintext"
        default: return "doc"
        }
    }
}

// MARK: - Document Picker Representable
private struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFiles: [URL]

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

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedFiles.append(contentsOf: urls)
        }
    }
}
