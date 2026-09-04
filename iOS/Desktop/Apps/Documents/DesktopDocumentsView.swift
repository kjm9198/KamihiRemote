import SwiftUI

/// Native long-form writing surface shown on the external desktop.
/// Editing/navigation is owned by the iPhone controller because external-display
/// scenes are non-interactive on iOS.
struct DesktopDocumentsView: View {
    @StateObject private var store = DesktopDocumentsStore.shared

    var body: some View {
        HStack(spacing: 0) {
            documentSidebar
                .frame(width: 190)

            Divider()

            documentCanvas
        }
        .background(KamihiTheme.Colors.surfaceBackground)
    }

    private var documentSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Documents", systemImage: "doc.text.fill")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 14)

            Text("Use the iPhone keyboard to write. New, switch and export controls are under More on the phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.documents) { document in
                        HStack(spacing: 8) {
                            Image(systemName: document.id == store.activeDocumentID ? "doc.text.fill" : "doc.text")
                                .foregroundStyle(document.id == store.activeDocumentID ? Color.accentColor : .secondary)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.title)
                                    .font(.subheadline.weight(document.id == store.activeDocumentID ? .semibold : .regular))
                                    .lineLimit(2)
                                Text(document.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            document.id == store.activeDocumentID ? Color.accentColor.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(document.id == store.activeDocumentID ? "Active document" : "")
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .background(Color.primary.opacity(0.035))
    }

    private var documentCanvas: some View {
        Group {
            if let document = store.activeDocument {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(document.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .textSelection(.enabled)
                            Text("Updated \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        if document.body.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "keyboard.badge.ellipsis")
                                    .font(.system(size: 34, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Start writing from the iPhone keyboard")
                                    .font(.headline)
                                Text("Your document saves locally as you type. Use More on the iPhone to create, switch, export or delete documents.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 480)
                            }
                            .frame(maxWidth: .infinity, minHeight: 260)
                        } else {
                            Text(document.body)
                                .font(.system(size: 17))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .accessibilityLabel("Document body")
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 760, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                ContentUnavailableView(
                    "No document selected",
                    systemImage: "doc.text",
                    description: Text("Create a document from More on the iPhone controller.")
                )
            }
        }
    }
}
