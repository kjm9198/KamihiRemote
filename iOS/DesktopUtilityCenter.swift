import SwiftUI
import UIKit

@MainActor
final class DesktopCalculatorStore: ObservableObject {
    static let shared = DesktopCalculatorStore()

    @Published var expression = ""
    @Published var result = "0"

    private init() {}

    func append(_ token: String) {
        expression.append(token)
        evaluatePreview()
    }

    func clear() {
        expression = ""
        result = "0"
    }

    func backspace() {
        guard !expression.isEmpty else { return }
        expression.removeLast()
        evaluatePreview()
    }

    func evaluate() {
        let normalized = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
        guard isSafe(normalized) else {
            result = "Error"
            return
        }
        var parser = ArithmeticParser(normalized)
        guard let value = parser.parse(), value.isFinite else {
            result = "Error"
            return
        }
        result = value.rounded() == value ? String(Int(value)) : String(format: "%.8g", value)
    }

    private func evaluatePreview() {
        guard !expression.isEmpty else {
            result = "0"
            return
        }
        evaluate()
    }

    private func isSafe(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        return !value.isEmpty && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private struct ArithmeticParser {
        private let characters: [Character]
        private var index = 0

        init(_ expression: String) {
            characters = Array(expression.filter { !$0.isWhitespace })
        }

        mutating func parse() -> Double? {
            guard let value = parseExpression(), index == characters.count else { return nil }
            return value
        }

        private mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let token = current, token == "+" || token == "-" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = token == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }
            while let token = current, token == "*" || token == "/" {
                index += 1
                guard let rhs = parseFactor() else { return nil }
                if token == "/" && rhs == 0 { return nil }
                value = token == "*" ? value * rhs : value / rhs
            }
            return value
        }

        private mutating func parseFactor() -> Double? {
            if current == "+" { index += 1; return parseFactor() }
            if current == "-" { index += 1; return parseFactor().map { -$0 } }
            if current == "(" {
                index += 1
                guard let value = parseExpression(), current == ")" else { return nil }
                index += 1
                return value
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            let start = index
            var dotCount = 0
            while let token = current, token.isNumber || token == "." {
                if token == "." { dotCount += 1 }
                if dotCount > 1 { return nil }
                index += 1
            }
            guard index > start else { return nil }
            return Double(String(characters[start..<index]))
        }

        private var current: Character? {
            index < characters.count ? characters[index] : nil
        }
    }
}

@MainActor
extension DesktopSession {
    func resizeActive(widthDelta: CGFloat, heightDelta: CGFloat) {
        guard let id = activeWindowID,
              let index = windows.firstIndex(where: { $0.id == id }),
              !windows[index].isMaximized else { return }

        var frame = windows[index].normalizedFrame
        let newWidth = min(max(frame.width + widthDelta, 0.28), 0.976 - frame.minX)
        let newHeight = min(max(frame.height + heightDelta, 0.24), 0.89 - frame.minY)
        frame.size = CGSize(width: newWidth, height: newHeight)
        windows[index].normalizedFrame = frame
    }

    func centerActiveWindow() {
        guard let id = activeWindowID,
              let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMaximized = false
        windows[index].isMinimized = false
        let width = min(max(windows[index].normalizedFrame.width, 0.48), 0.82)
        let height = min(max(windows[index].normalizedFrame.height, 0.46), 0.76)
        windows[index].normalizedFrame = CGRect(
            x: (1 - width) / 2,
            y: max(0.055, (0.89 - height) / 2),
            width: width,
            height: height
        )
    }

    func restoreAllWindows() {
        for index in windows.indices { windows[index].isMinimized = false }
        activeWindowID = windows.last?.id
    }

    func minimizeAllWindows() {
        for index in windows.indices { windows[index].isMinimized = true }
        activeWindowID = nil
    }
}

struct DesktopClipboardCenterView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var clipboard = DesktopClipboardStore.shared
    @ObservedObject private var notes = DesktopNotesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                if clipboard.items.isEmpty {
                    ContentUnavailableView("Clipboard Empty", systemImage: "doc.on.clipboard", description: Text("Copy text on the iPhone, then tap Refresh. Kamihi keeps this history only in memory."))
                } else {
                    ForEach(Array(clipboard.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item)
                                .lineLimit(4)
                                .textSelection(.enabled)
                            HStack(spacing: 10) {
                                Button("Paste", systemImage: "arrow.down.doc") {
                                    desktop.typeIntoActiveWebView(item)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Copy", systemImage: "doc.on.doc") {
                                    clipboard.copy(item)
                                }
                                .buttonStyle(.bordered)

                                Button("Notes", systemImage: "note.text.badge.plus") {
                                    if !notes.text.isEmpty { notes.text += "\n\n" }
                                    notes.text += item
                                    desktop.openNotes()
                                }
                                .buttonStyle(.bordered)

                                ShareLink(item: item) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Share clipboard item")
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Label("Kamihi does not persist clipboard history. Refresh reads the current iOS pasteboard only when you ask it to or open this screen.", systemImage: "hand.raised.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Clipboard privacy. Kamihi does not persist clipboard history. Refresh reads the current iOS pasteboard only when requested or when this screen opens.")
                }
            }
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") { clipboard.captureIfChanged() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { confirmClear = true }
                        .disabled(clipboard.items.isEmpty && UIPasteboard.general.items.isEmpty)
                }
            }
            .confirmationDialog(
                "Clear clipboard?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear iOS Clipboard & Kamihi History", role: .destructive) {
                    UIPasteboard.general.items = []
                    clipboard.clear()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes Kamihi's in-memory history and clears the current iOS system clipboard. It cannot be undone.")
            }
        }
        .onAppear { clipboard.captureIfChanged() }
    }
}

struct DesktopCalculatorView: View {
    @ObservedObject private var calculator = DesktopCalculatorStore.shared
    @Environment(\.dismiss) private var dismiss

    private let rows = [
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "−"],
        ["0", ".", "(", ")"],
        ["C", "⌫", "+", "="]
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(calculator.expression.isEmpty ? "0" : calculator.expression)
                        .font(.title3.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(calculator.result)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            Button { press(key) } label: {
                                Text(key)
                                    .font(.title2.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 54)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Calculator")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func press(_ key: String) {
        switch key {
        case "C": calculator.clear()
        case "⌫": calculator.backspace()
        case "=": calculator.evaluate()
        default: calculator.append(key)
        }
    }
}
