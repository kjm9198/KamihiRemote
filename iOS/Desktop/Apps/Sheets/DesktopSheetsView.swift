import SwiftUI

/// Lightweight native spreadsheet surface for the external desktop.
/// Pointer clicks select a cell; editing is routed through the iPhone keyboard.
struct DesktopSheetsView: View {
    @StateObject private var store = DesktopSheetsStore.shared

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
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(KamihiTheme.Colors.surfaceBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spreadsheet \(store.workbook.title), active cell \(store.activeCellName)")
    }
}
