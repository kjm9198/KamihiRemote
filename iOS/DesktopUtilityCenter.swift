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
        let value = NSExpression(format: normalized).expressionValue(with: nil, context: nil)
        if let number = value as? NSNumber {
            let double = number.doubleValue
            result = double.rounded() == double ? String(Int(double)) : String(format: "%.8g", double)
        } else {
            result = "Error"
        }
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

struct DesktopAppLauncherView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct AppItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let action: @MainActor (DesktopSession) -> Void
    }

    private var apps: [AppItem] {
        [
            AppItem(id: "chatgpt", title: "ChatGPT", subtitle: "AI workspace", icon: "sparkles") { $0.openChatGPT() },
            AppItem(id: "youtube", title: "YouTube", subtitle: "Video and tutorials", icon: "play.rectangle.fill") { $0.openYouTube() },
            AppItem(id: "browser", title: "Browser", subtitle: "Desktop web", icon: "safari") { $0.openBrowser() },
            AppItem(id: "notes", title: "Notes", subtitle: "Offline notes", icon: "note.text") { $0.openNotes() },
            AppItem(id: "vibe", title: "Vibe Workspace", subtitle: "ChatGPT + YouTube + Notes", icon: "rectangle.3.group") { $0.openVibeWorkspace() }
        ]
    }

    private var filtered: [AppItem] {
        guard !query.isEmpty else { return apps }
        let q = query.lowercased()
        return apps.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                    ForEach(filtered) { app in
                        Button {
                            app.action(desktop)
                            dismiss()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: app.icon)
                                    .font(.system(size: 30, weight: .medium))
                                    .frame(width: 58, height: 58)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                Text(app.title).font(.headline)
                                Text(app.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(app.title)
                        .accessibilityHint(app.subtitle)
                    }
                }
                .padding()
            }
            .searchable(text: $query, prompt: "Search desktop apps")
            .navigationTitle("Apps")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct DesktopWindowOverviewView: View {
    @EnvironmentObject private var desktop: DesktopSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if desktop.windows.isEmpty {
                    ContentUnavailableView("No Windows", systemImage: "rectangle.on.rectangle.slash", description: Text("Open an app from the launcher."))
                } else {
                    ForEach(desktop.windows.reversed()) { window in
                        Button {
                            desktop.restoreAndActivate(window.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: window.title))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(window.title).foregroundStyle(.primary)
                                    Text(window.isMinimized ? "Minimized" : (window.isMaximized ? "Maximized" : "Running"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if window.id == desktop.activeWindowID {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Window Overview")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Restore All") { desktop.restoreAllWindows() }
                    Spacer()
                    Button("Minimize All") { desktop.minimizeAllWindows() }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func icon(for title: String) -> String {
        switch title {
        case "ChatGPT": return "sparkles"
        case "YouTube": return "play.rectangle.fill"
        case "Notes": return "note.text"
        case "Browser": return "safari"
        default: return "macwindow"
        }
    }
}

struct DesktopClipboardCenterView: View {
    @ObservedObject private var clipboard = DesktopClipboardStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if clipboard.items.isEmpty {
                    ContentUnavailableView("Clipboard Empty", systemImage: "doc.on.clipboard", description: Text("Copy text on the iPhone, then reopen this panel."))
                } else {
                    ForEach(Array(clipboard.items.enumerated()), id: \.offset) { _, item in
                        Button {
                            clipboard.copy(item)
                            dismiss()
                        } label: {
                            Text(item)
                                .lineLimit(3)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Refresh") { clipboard.captureIfChanged() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Clear", role: .destructive) { clipboard.clear() } }
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
