import Foundation
import UIKit

/// Persistent lightweight spreadsheet model for Kamihi Desktop.
///
/// The external canvas is display-only, so pointer clicks select cells and the
/// iPhone keyboard edits the selected cell. Data remains local unless the user
/// explicitly imports/exports CSV through standard iOS document/share surfaces.
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
        didSet { scheduleSave() }
    }

    private let storageKey = "kamihi.desktop.sheets.v1"
    private let saveDelayNanoseconds: UInt64 = 400_000_000
    private var saveTask: Task<Void, Never>?
    private var lifecycleObservers: [NSObjectProtocol] = []

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

        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.flushPendingSave()
                }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.flushPendingSave()
                }
            }
        )
    }

    deinit {
        saveTask?.cancel()
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
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

    /// Imports a user-selected CSV into the local workbook. Security-scoped file
    /// access is held only while reading the selected document. Values beyond the
    /// current lightweight 20x12 grid are intentionally ignored instead of being
    /// silently persisted somewhere inaccessible.
    @discardableResult
    func importCSV(from url: URL) -> Bool {
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return false
        }

        let rows = Self.parseCSV(text)
        guard !rows.isEmpty else { return false }

        var cells: [String: String] = [:]
        for (rowIndex, row) in rows.prefix(Self.rowCount).enumerated() {
            for (columnIndex, value) in row.prefix(Self.columnCount).enumerated() where !value.isEmpty {
                cells[Self.cellKey(row: rowIndex, column: columnIndex)] = value
            }
        }

        let importedTitle = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        workbook = Workbook(
            title: importedTitle.isEmpty ? "Imported Sheet" : importedTitle,
            cells: cells,
            activeRow: 0,
            activeColumn: 0,
            updatedAt: Date()
        )
        flushPendingSave()
        return true
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

    /// Small RFC-4180-style parser that handles quoted commas, escaped quotes,
    /// CRLF, and quoted line breaks without depending on a third-party library.
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field.removeAll(keepingCapacity: true)
        }

        func finishRow() {
            finishField()
            rows.append(row)
            row.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if character == "\"" {
                if insideQuotes, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = text.index(after: next)
                    continue
                }
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                finishField()
            } else if (character == "\n" || character == "\r") && !insideQuotes {
                if character == "\r", next < text.endIndex, text[next] == "\n" {
                    index = next
                }
                finishRow()
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }

    private func clampSelection() {
        workbook.activeRow = min(max(workbook.activeRow, 0), Self.rowCount - 1)
        workbook.activeColumn = min(max(workbook.activeColumn, 0), Self.columnCount - 1)
    }

    /// Collapse rapid spreadsheet mutations into one trailing persistence write.
    /// This avoids re-encoding the entire workbook for every typed character.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: saveDelayNanoseconds)
            guard !Task.isCancelled else { return }
            saveNow()
            saveTask = nil
        }
    }

    /// Flush the last editing burst before iOS suspends or terminates the app.
    private func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        saveNow()
    }

    private func saveNow() {
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
