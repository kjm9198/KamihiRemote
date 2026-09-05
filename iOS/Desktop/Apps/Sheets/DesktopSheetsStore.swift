import Foundation
import UIKit

/// Persistent lightweight spreadsheet model for Kamihi Desktop.
///
/// The external canvas is display-only, so pointer clicks select cells and the
/// iPhone keyboard edits the selected cell. Data remains local unless the user
/// explicitly exports a CSV through the standard iOS share sheet.
@MainActor
final class DesktopSheetsStore: ObservableObject {
    static let shared = DesktopSheetsStore()

    struct Workbook: Codable, Equatable {
        var title: String
        var cells: [String: String]
        var activeRow: Int
        var activeColumn: Int
        var updatedAt: Date
    }

    static let rowCount = 20
    static let columnCount = 12

    @Published private(set) var workbook: Workbook {
        didSet { save() }
    }

    private let storageKey = "kamihi.desktop.sheets.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Workbook.self, from: data) {
            workbook = saved
        } else {
            workbook = Workbook(
                title: "Untitled Sheet",
                cells: [:],
                activeRow: 0,
                activeColumn: 0,
                updatedAt: Date()
            )
        }
        clampSelection()
    }

    var activeRow: Int { workbook.activeRow }
    var activeColumn: Int { workbook.activeColumn }

    var activeCellName: String {
        Self.columnName(activeColumn) + String(activeRow + 1)
    }

    var activeCellValue: String {
        value(row: activeRow, column: activeColumn)
    }

    func value(row: Int, column: Int) -> String {
        workbook.cells[Self.cellKey(row: row, column: column)] ?? ""
    }

    func select(row: Int, column: Int) {
        workbook.activeRow = min(max(row, 0), Self.rowCount - 1)
        workbook.activeColumn = min(max(column, 0), Self.columnCount - 1)
    }

    /// Maps a normalized point inside the Sheets content view to the fixed grid.
    /// The first 6%/8% are row/column headers; the rest is an even 12×20 grid.
    func select(normalizedPoint point: CGPoint) {
        let x = min(max(point.x, 0), 1)
        let y = min(max(point.y, 0), 1)
        let rowHeader: CGFloat = 0.06
        let columnHeader: CGFloat = 0.08
        guard x >= rowHeader, y >= columnHeader else { return }

        let column = Int(((x - rowHeader) / (1 - rowHeader)) * CGFloat(Self.columnCount))
        let row = Int(((y - columnHeader) / (1 - columnHeader)) * CGFloat(Self.rowCount))
        select(row: min(row, Self.rowCount - 1), column: min(column, Self.columnCount - 1))
    }

    func appendToActiveCell(_ text: String) {
        guard !text.isEmpty else { return }
        let key = Self.cellKey(row: activeRow, column: activeColumn)
        workbook.cells[key, default: ""].append(text)
        workbook.updatedAt = Date()
    }

    func deleteBackwardFromActiveCell() {
        let key = Self.cellKey(row: activeRow, column: activeColumn)
        guard var value = workbook.cells[key], !value.isEmpty else { return }
        value.removeLast()
        if value.isEmpty {
            workbook.cells.removeValue(forKey: key)
        } else {
            workbook.cells[key] = value
        }
        workbook.updatedAt = Date()
    }

    /// Return commits the current cell and advances downward like a spreadsheet.
    func commitAndMoveDown() {
        select(row: min(activeRow + 1, Self.rowCount - 1), column: activeColumn)
    }

    func clearActiveCell() {
        workbook.cells.removeValue(forKey: Self.cellKey(row: activeRow, column: activeColumn))
        workbook.updatedAt = Date()
    }

    @discardableResult
    func exportCSV() -> Bool {
        var lines: [String] = []
        for row in 0..<Self.rowCount {
            let values = (0..<Self.columnCount).map { column in
                Self.csvEscaped(value(row: row, column: column))
            }
            lines.append(values.joined(separator: ","))
        }

        guard let data = lines.joined(separator: "\n").data(using: .utf8) else { return false }
        let safeTitle = workbook.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (safeTitle.isEmpty ? "Kamihi Sheet" : safeTitle) + ".csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return false
        }

        guard let presenter = Self.topViewController() else { return false }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 1, width: 1, height: 1)
        }
        presenter.present(activity, animated: true)
        return true
    }

    static func columnName(_ column: Int) -> String {
        guard column >= 0 else { return "A" }
        return String(UnicodeScalar(65 + min(column, 25))!)
    }

    private static func cellKey(row: Int, column: Int) -> String {
        "\(row):\(column)"
    }

    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func clampSelection() {
        workbook.activeRow = min(max(workbook.activeRow, 0), Self.rowCount - 1)
        workbook.activeColumn = min(max(workbook.activeColumn, 0), Self.columnCount - 1)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workbook) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
