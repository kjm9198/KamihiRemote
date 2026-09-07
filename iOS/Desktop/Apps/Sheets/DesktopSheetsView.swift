import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Lightweight native spreadsheet surface for the external desktop. The grid
/// remains fully local and pointer-driven while its toolbar and headers now use
/// the same compact desktop visual language as the rest of Kamihi.
struct DesktopSheetsView: View {
    @StateObject private var store = DesktopSheetsStore.shared
    @State private var showCSVImporter = false
    @State private var importErrorMessage: String?
    @State private var clipboardStatus: String?

    private let rowHeaderWidth: CGFloat = 42
    private let columnHeaderHeight: CGFloat = 28
    private let cellWidth: CGFloat = 112
    private let cellHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(DesktopShellPalette.secondaryCanvas.opacity(0.80))
                            .frame(width: rowHeaderWidth, height: columnHeaderHeight)
                            .overlay {
                                Image(systemName: "tablecells")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                        ForEach(0..<DesktopSheetsStore.columnCount, id: \.self) { column in
                            Text(DesktopSheetsStore.columnName(column))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: cellWidth, height: columnHeaderHeight)
                                .background(DesktopShellPalette.secondaryCanvas.opacity(0.72))
                                .overlay(alignment: .trailing) { gridDivider }
                        }
                    }

                    ForEach(0..<DesktopSheetsStore.rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            Text(String(row + 1))
                                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: rowHeaderWidth, height: cellHeight)
                                .background(DesktopShellPalette.secondaryCanvas.opacity(0.58))
                                .overlay(alignment: .bottom) { gridDivider }

                            ForEach(0..<DesktopSheetsStore.columnCount, id: \.self) { column in
                                sheetCell(row: row, column: column, width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
                .frame(
                    width: rowHeaderWidth + (cellWidth * CGFloat(DesktopSheetsStore.columnCount)),
                    height: columnHeaderHeight + (cellHeight * CGFloat(DesktopSheetsStore.rowCount)),
                    alignment: .topLeading
                )
            }
            .scrollIndicators(.automatic)
            .accessibilityLabel("Spreadsheet grid. Scroll vertically and horizontally to reach cells.")
        }
        .background(DesktopShellPalette.canvas)
        .fileImporter(
            isPresented: $showCSVImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first, store.importCSV(from: url) else {
                    importErrorMessage = "Kamihi could not read that file as CSV. Choose a UTF-8 or UTF-16 comma-separated file."
                    return
                }
                importErrorMessage = nil
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError {
                    importErrorMessage = "The iOS document picker could not open that CSV."
                }
            }
        }
        .alert("Sheets File Error", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "Unknown file error")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spreadsheet \(store.workbook.title), active cell \(store.activeCellName)")
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 26, height: 26)
                .background(Color.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(store.workbook.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text("Cell \(store.activeCellName)")
                    .font(.system(size: 9.5, weight: .medium).monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let clipboardStatus {
                Text(clipboardStatus)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            } else {
                Text("Type on iPhone · Return moves down")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Button(action: copyActiveCell) {
                DesktopToolbarIconLabel("doc.on.doc")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(store.activeCellName)")
            .accessibilityHint("Copies the selected cell to the iOS clipboard.")

            Button(action: pasteClipboard) {
                DesktopToolbarIconLabel("doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .disabled(UIPasteboard.general.string == nil)
            .accessibilityLabel("Paste into \(store.activeCellName)")
            .accessibilityHint("Pastes text or a tab-separated table starting at the selected cell.")

            Button(role: .destructive, action: clearActiveCell) {
                DesktopToolbarIconLabel("delete.left")
            }
            .buttonStyle(.plain)
            .disabled(store.activeCellValue.isEmpty)
            .accessibilityLabel("Clear \(store.activeCellName)")
            .accessibilityHint("Clears the selected cell.")

            Button { showCSVImporter = true } label: {
                DesktopToolbarIconLabel("square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Import CSV")

            Button {
                if !store.exportCSV() {
                    importErrorMessage = "Kamihi could not open the iOS share sheet for this CSV."
                }
            } label: {
                DesktopToolbarIconLabel("square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export CSV")
        }
        .padding(.horizontal, 10)
        .frame(height: DesktopShellMetrics.toolbarHeight)
        .desktopAppToolbar()
    }

    private var gridDivider: some View {
        Rectangle()
            .fill(DesktopShellPalette.separator.opacity(0.20))
            .frame(width: 0.5)
    }

    private func sheetCell(row: Int, column: Int, width: CGFloat, height: CGFloat) -> some View {
        let isActive = row == store.activeRow && column == store.activeColumn
        let cellName = "\(DesktopSheetsStore.columnName(column))\(row + 1)"
        let cellValue = store.value(row: row, column: column)

        return Text(cellValue)
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
            .padding(.horizontal, 5)
            .frame(width: width, height: height, alignment: .leading)
            .background(isActive ? Color.accentColor.opacity(0.12) : DesktopShellPalette.canvas)
            .overlay {
                Rectangle()
                    .strokeBorder(
                        isActive ? Color.accentColor : DesktopShellPalette.separator.opacity(0.18),
                        lineWidth: isActive ? 1.5 : 0.5
                    )
            }
            .contentShape(Rectangle())
            .onTapGesture { store.select(row: row, column: column) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cellName)
            .accessibilityValue(cellValue.isEmpty ? "Empty" : cellValue)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(isActive ? "Selected cell. Type on the iPhone to edit." : "Activate to select this cell for editing.")
            .accessibilityAction { store.select(row: row, column: column) }
            .accessibilityAction(named: "Move Up") { store.select(row: row - 1, column: column) }
            .accessibilityAction(named: "Move Down") { store.select(row: row + 1, column: column) }
            .accessibilityAction(named: "Move Left") { store.select(row: row, column: column - 1) }
            .accessibilityAction(named: "Move Right") { store.select(row: row, column: column + 1) }
    }

    private func copyActiveCell() {
        UIPasteboard.general.string = store.activeCellValue
        showClipboardStatus("Copied \(store.activeCellName)")
    }

    private func pasteClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showClipboardStatus("Clipboard is empty")
            return
        }
        let startCell = store.activeCellName
        store.appendToActiveCell(text)
        showClipboardStatus("Pasted at \(startCell)")
    }

    private func clearActiveCell() {
        let cell = store.activeCellName
        store.clearActiveCell()
        showClipboardStatus("Cleared \(cell)")
    }

    private func showClipboardStatus(_ message: String) {
        clipboardStatus = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if clipboardStatus == message {
                clipboardStatus = nil
            }
        }
    }
}
