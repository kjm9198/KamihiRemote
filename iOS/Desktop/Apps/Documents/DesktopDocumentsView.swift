import SwiftUI

/// Native long-form writing surface. It keeps the existing local document store
/// but presents it like a desktop editor: edge-to-edge document sidebar, uniform
/// toolbar and a centered paper/canvas rather than an oversized iPad card.
struct DesktopDocumentsView: View {
    @StateObject private var store = DesktopDocumentsStore.shared

    var body: some View {
        HStack(spacing: 0) {
            documentSidebar
                .frame(width: DesktopShellMetrics.sidebarWidth)

            documentCanvas
        }
        .background(DesktopShellPalette.canvas)
    }

    private var documentSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Documents")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    store.createDocument()
                } label: {
                    DesktopToolbarIconLabel("square.and.pencil")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New document")
            }
            .padding(.horizontal, 11)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.documents) { document in
                        Button {
                            store.select(document.id)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: document.id == store.activeDocumentID ? "doc.text.fill" : "doc.text")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(document.id == store.activeDocumentID ? Color.blue : Color.secondary)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(document.title)
                                        .font(.system(size: 12.5, weight: document.id == store.activeDocumentID ? .semibold : .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(document.updatedAt, style: .relative)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 46)
                            .background(
                                document.id == store.activeDocumentID ? Color.accentColor.opacity(0.14) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(document.id == store.activeDocumentID ? "Selected" : "")
                    }
                }
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Saved on this iPhone", systemImage: "iphone")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Use the phone keyboard to edit the active document.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(11)
        }
        .desktopSidebarSurface()
    }

    @ViewBuilder
    private var documentCanvas: some View {
        if let document = store.activeDocument {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(document.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text("Edited \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Button {
                        store.createDocument()
                    } label: {
                        DesktopToolbarIconLabel("plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New document")
                }
                .padding(.horizontal, 12)
                .frame(height: DesktopShellMetrics.toolbarHeight)
                .desktopAppToolbar()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(document.title)
                            .font(.system(size: 25, weight: .bold))
                            .tracking(-0.5)
                            .textSelection(.enabled)

                        Rectangle()
                            .fill(DesktopShellPalette.separator.opacity(0.20))
                            .frame(height: 0.5)

                        if document.body.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundStyle(.tertiary)
                                Text("Start writing from the iPhone keyboard")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Your document saves locally as you type and returns with your desktop session.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 280)
                        } else {
                            Text(document.body)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .accessibilityLabel("Document body")
                        }
                    }
                    .background(DesktopNativeScrollBridge(key: "Documents"))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 34)
                    .frame(maxWidth: 760, minHeight: 520, alignment: .topLeading)
                    .background(DesktopShellPalette.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DesktopShellPalette.separator.opacity(0.16), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 14, y: 6)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(DesktopShellPalette.secondaryCanvas.opacity(0.55))
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No document selected")
                    .font(.system(size: 15, weight: .semibold))
                Button("New Document") { store.createDocument() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesktopShellPalette.canvas)
        }
    }
}
