import SwiftUI
import UIKit

@MainActor
final class DesktopCalculatorStore: ObservableObject {
    static let shared = DesktopCalculatorStore()

    @Published var expression = ""
    @Published var result = "0"

    private static let binaryOperators: Set<Character> = ["+", "−", "×", "÷"]
    private init() {}

    func append(_ token: String) {
        guard let character = token.first, token.count == 1 else { return }

        if character.isNumber {
            expression.append(character)
            evaluatePreview()
            return
        }

        switch character {
        case ".":
            appendDecimalPoint()
        case "+", "−", "×", "÷":
            appendOperator(character)
        case "(":
            if let last = expression.last, last.isNumber || last == ")" {
                expression.append("×")
            }
            expression.append(character)
        case ")":
            guard unmatchedOpeningParentheses > 0,
                  let last = expression.last,
                  last.isNumber || last == ")" else { return }
            expression.append(character)
        default:
            return
        }
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
        let normalized = normalizedExpression
        guard isSafe(normalized) else {
            result = "Error"
            return
        }
        var parser = ArithmeticParser(normalized)
        guard let value = parser.parse(), value.isFinite else {
            result = "Error"
            return
        }
        result = format(value)
    }

    private var normalizedExpression: String {
        expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
    }

    private var unmatchedOpeningParentheses: Int {
        expression.reduce(into: 0) { count, character in
            if character == "(" { count += 1 }
            if character == ")" { count = max(0, count - 1) }
        }
    }

    private func appendDecimalPoint() {
        let currentNumber = expression.reversed().prefix { character in
            character.isNumber || character == "."
        }
        guard !currentNumber.contains(".") else { return }
        if currentNumber.isEmpty {
            expression.append("0")
        }
        expression.append(".")
    }

    private func appendOperator(_ newOperator: Character) {
        guard !expression.isEmpty else {
            if newOperator == "−" { expression.append(newOperator) }
            return
        }

        if let last = expression.last, Self.binaryOperators.contains(last) {
            expression.removeLast()
            expression.append(newOperator)
            return
        }

        guard expression.last != "(" else {
            if newOperator == "−" { expression.append(newOperator) }
            return
        }
        expression.append(newOperator)
    }

    private func evaluatePreview() {
        guard !expression.isEmpty else {
            result = "0"
            return
        }

        // In-progress keypad input such as `12+`, `(` or `4×(` is not an error.
        // Keep the most recent valid result visible until the expression can be
        // parsed again, and reserve Error for an explicit equals evaluation.
        guard let last = expression.last,
              !Self.binaryOperators.contains(last),
              last != "(",
              unmatchedOpeningParentheses == 0 else { return }

        let normalized = normalizedExpression
        guard isSafe(normalized) else { return }
        var parser = ArithmeticParser(normalized)
        guard let value = parser.parse(), value.isFinite else { return }
        result = format(value)
    }

    private func format(_ value: Double) -> String {
        // Avoid trapping on Double -> Int conversion when a valid calculation is
        // integral but outside the platform Int range.
        if value.rounded() == value,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            return String(Int(value))
        }
        return String(format: "%.8g", value)
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

/// Clipboard counterpart for the desktop. History remains memory-only by design;
/// the UI now behaves as a regular Kamihi window rather than an iPhone sheet.
struct DesktopClipboardCenterView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @ObservedObject private var clipboard = DesktopClipboardStore.shared
    @ObservedObject private var notes = DesktopNotesStore.shared
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 26, height: 26)
                    .background(Color.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { clipboard.captureIfChanged() } label: {
                    DesktopToolbarIconLabel("arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh clipboard")
                Button(role: .destructive) { confirmClear = true } label: {
                    DesktopToolbarIconLabel("trash")
                }
                .buttonStyle(.plain)
                .disabled(clipboard.items.isEmpty && UIPasteboard.general.items.isEmpty)
                .accessibilityLabel("Clear clipboard")
            }
            .padding(.horizontal, 10)
            .frame(height: DesktopShellMetrics.toolbarHeight)
            .desktopAppToolbar()

            if clipboard.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Clipboard Empty")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Copy text on the iPhone, then refresh. Kamihi keeps clipboard history only in memory.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(clipboard.items.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item)
                                    .font(.system(size: 12.5))
                                    .lineLimit(5)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 6) {
                                    Button("Paste", systemImage: "arrow.down.doc") {
                                        desktop.typeIntoActiveDesktopField(item)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Copy", systemImage: "doc.on.doc") { clipboard.copy(item) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                    Button("Notes", systemImage: "note.text.badge.plus") {
                                        if !notes.text.isEmpty { notes.text += "\n\n" }
                                        notes.text += item
                                        desktop.openNotes()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    ShareLink(item: item) {
                                        Image(systemName: "square.and.arrow.up")
                                            .frame(width: 26, height: 26)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .accessibilityLabel("Share clipboard item")
                                }
                            }
                            .padding(12)
                            .desktopInsetPanel()
                        }
                    }
                    .padding(14)
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.secondary)
                Text("Clipboard history is not written to disk. Refresh reads the current iOS pasteboard only when requested.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .desktopAppToolbar()
        }
        .background(DesktopShellPalette.canvas)
        .onAppear { clipboard.captureIfChanged() }
        .confirmationDialog("Clear clipboard?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear iOS Clipboard & Kamihi History", role: .destructive) {
                UIPasteboard.general.items = []
                clipboard.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes Kamihi's in-memory history and clears the current iOS system clipboard. It cannot be undone.")
        }
    }
}

/// Calculator counterpart using the same local parser, wrapped in compact desktop
/// chrome with large legible controls for the glasses display.
struct DesktopCalculatorView: View {
    @ObservedObject private var calculator = DesktopCalculatorStore.shared

    private let rows = [
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "−"],
        ["0", ".", "(", ")"],
        ["C", "⌫", "+", "="]
    ]

    var body: some View {
        GeometryReader { calculatorGeo in
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 26, height: 26)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text("Calculator")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button { calculator.clear() } label: {
                        DesktopToolbarIconLabel("clear")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear calculator")
                    .desktopCalculatorHitTarget(.toolbarClear, containerSize: calculatorGeo.size)
                }
                .padding(.horizontal, 10)
                .frame(height: DesktopShellMetrics.toolbarHeight)
                .desktopAppToolbar()

                VStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(calculator.expression.isEmpty ? "0" : calculator.expression)
                            .font(.system(size: 16, weight: .regular).monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(calculator.result)
                            .font(.system(size: 38, weight: .medium))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityLabel("Result")
                            .accessibilityValue(calculator.result)
                    }
                    .padding(14)
                    .desktopInsetPanel()

                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { key in
                                Button { press(key) } label: {
                                    Text(key)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(key == "=" ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity, minHeight: 46)
                                        .background(
                                            key == "=" ? Color.accentColor : Color.primary.opacity(0.065),
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(accessibilityLabel(for: key))
                                .desktopCalculatorHitTarget(.key(key), containerSize: calculatorGeo.size)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
            .coordinateSpace(name: "desktopCalculatorContent")
            .onPreferenceChange(DesktopCalculatorHitPreferenceKey.self) { preferences in
                DesktopCalculatorHitRegistry.shared.update(
                    entries: preferences.map {
                        DesktopCalculatorHitRegistry.Entry(
                            target: $0.target,
                            normalizedFrame: $0.normalizedFrame
                        )
                    }
                )
            }
            .onDisappear {
                DesktopCalculatorHitRegistry.shared.clear()
            }
        }
        .background(DesktopShellPalette.canvas)
    }

    private func press(_ key: String) {
        switch key {
        case "C": calculator.clear()
        case "⌫": calculator.backspace()
        case "=": calculator.evaluate()
        default: calculator.append(key)
        }
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "÷": "Divide"
        case "×": "Multiply"
        case "−": "Subtract"
        case "+": "Add"
        case "=": "Equals"
        case "⌫": "Delete last digit"
        case "C": "Clear"
        case ".": "Decimal point"
        case "(": "Open parenthesis"
        case ")": "Close parenthesis"
        default: key
        }
    }
}
