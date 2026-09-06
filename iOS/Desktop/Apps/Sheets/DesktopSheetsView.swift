import SwiftUI
import UniformTypeIdentifiers

/// Lightweight native spreadsheet surface for the external desktop.
/// Pointer clicks select a cell; editing is routed through the iPhone keyboard.
struct DesktopSheetsView: View {
    @StateObject private var store = DesktopSheetsStore.shared
    @State private var showCSVImporter = false
    @State private var importErrorMessage: String?

    private let rowHeaderWidth: CGFloat = 44
    private let columnHeaderHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Sheets", systemImage: "tablecells.fill")
                    .font(.headline)
                Text(store.workbook.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Cell \(store.activeCellName)")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Type on the iPhone • Return moves down")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showCSVImporter = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Opens the iOS document picker and replaces this sheet with the selected CSV file.")

                Button {
                    if !store.exportCSV() {
                        importErrorMessage = "Kamihi could not open the iOS share sheet for this CSV."
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Exports the current sheet as CSV through the standard iOS share sheet.")
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.primary.opacity(0.035))

            GeometryReader { geo in
                let cellWidth = max(54, (geo.size.width - rowHeaderWidth) / CGFloat(DesktopSheetsStore.columnCount))
                let cellHeight = max(22, (geo.size.height - columnHeaderHeight) / CGFloat(DesktopSheetsStore.rowCount))

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: rowHeaderWidth, height: columnHeaderHeight)
                            .overlay {
                                Image(systemName: "tablecells")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        ForEach(0..<DesktopSheetsStore.columnCount, id: \.self) { column in
                            Text(DesktopSheetsStore.columnName(column))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: cellWidth, height: columnHeaderHeight)
                                .background(Color.primary.opacity(0.045))
                                .overlay(alignment: .trailing) { Divider() }
                        }
                    }

                    ForEach(0..<DesktopSheetsStore.rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            Text(String(row + 1))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: rowHeaderWidth, height: cellHeight)
                                .background(Color.primary.opacity(0.04))
                                .overlay(alignment: .bottom) { Divider() }

                            ForEach(0..<DesktopSheetsStore.columnCount, id: \.self) { column in
                                let isActive = row == store.activeRow && column == store.activeColumn
                                Text(store.value(row: row, column: column))
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 5)
                                    .frame(width: cellWidth, height: cellHeight, alignment: .leading)
                                    .background(isActive ? Color.accentColor.opacity(0.13) : Color.clear)
                                    .overlay {
                                        Rectangle()
                                            .strokeBorder(
                                                isActive ? Color.accentColor : Color.primary.opacity(0.08),
                                                lineWidth: isActive ? 2 : 0.5
                                            )
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(DesktopSheetsStore.columnName(column))\(row + 1)")
                                    .accessibilityValue(store.value(row: row, column: column).isEmpty ? "Empty" : store.value(row: row, column: column))
                                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                                    .accessibilityHint(isActive ? "Selected cell. Type on the iPhone to edit. Use the custom actions to move directly to a neighboring cell." : "Activate to select this cell for editing.")
                                    .accessibilityAction {
                                        store.select(row: row, column: column)
                                    }
                                    .accessibilityAction(named: "Move Up") {
                                        store.select(row: row - 1, column: column)
                                    }
                                    .accessibilityAction(named: "Move Down") {
                                        store.select(row: row + 1, column: column)
                                    }
                                    .accessibilityAction(named: "Move Left") {
                                        store.select(row: row, column: column - 1)
                                    }
                                    .accessibilityAction(named: "Move Right") {
                                        store.select(row: row, column: column + 1)
                                    }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(KamihiTheme.Colors.surfaceBackground)
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
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Unknown file error")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spreadsheet \(store.workbook.title), active cell \(store.activeCellName)")
    }
}
