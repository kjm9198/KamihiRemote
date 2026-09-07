import Foundation
import UIKit

/// Persistent offline long-form document store for Kamihi Desktop.
///
/// The external display is non-interactive, so editing is intentionally routed
/// through the iPhone keyboard/controller. Documents stay local unless the user
/// explicitly invokes Export, which uses the standard iOS share sheet.
@MainActor
final class DesktopDocumentsStore: ObservableObject {
    static let shared = DesktopDocumentsStore()

    struct Document: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var body: String
        var updatedAt: Date

        init(id: UUID = UUID(), title: String, body: String = "", updatedAt: Date = Date()) {
            self.id = id
            self.title = title
            self.body = body
            self.updatedAt = updatedAt
        }
    }

    @Published private(set) var documents: [Document] = [] {
        didSet {
            guard !isRestoring else { return }
            saveDocuments()
        }
    }
    @Published private(set) var activeDocumentID: UUID? {
        didSet {
            guard !isRestoring else { return }
            saveActiveSelection()
        }
    }

    private let storageKey = "kamihi.desktop.documents.v1"
    private let activeDocumentStorageKey = "kamihi.desktop.documents.v1.active"
    private var isRestoring = false

    private init() {
        isRestoring = true
        let hadPersistedCollection = loadDocuments()

        if hadPersistedCollection {
            restoreActiveSelection()
        } else {
            seedInitialDocument()
        }

        if activeDocumentID == nil, !documents.isEmpty {
            activeDocumentID = documents.first?.id
        }
        isRestoring = false

        // Persist first-launch seeding once, but never reinterpret a deliberately
        // empty saved collection as first launch on a later process start.
        if !hadPersistedCollection {
            saveDocuments()
            saveActiveSelection()
        }
    }

    var activeDocument: Document? {
        documents.first(where: { $0.id == activeDocumentID })
    }

    func createDocument() {
        let nextNumber = documents.count + 1
        let title = nextNumber == 1 ? "Untitled Document" : "Untitled Document \(nextNumber)"
        let document = Document(title: title)
        documents.insert(document, at: 0)
        activeDocumentID = document.id
    }

    func select(_ id: UUID) {
        guard documents.contains(where: { $0.id == id }) else { return }
        activeDocumentID = id
    }

    func cycleDocument(forward: Bool = true) {
        guard !documents.isEmpty else { return }
        guard let activeDocumentID,
              let current = documents.firstIndex(where: { $0.id == activeDocumentID }) else {
            self.activeDocumentID = documents.first?.id
            return
        }

        let next: Int
        if forward {
            next = (current + 1) % documents.count
        } else {
            next = (current - 1 + documents.count) % documents.count
        }
        self.activeDocumentID = documents[next].id
    }

    func deleteActiveDocument() {
        guard let activeDocumentID,
              let removedIndex = documents.firstIndex(where: { $0.id == activeDocumentID }) else { return }

        documents.remove(at: removedIndex)
        guard !documents.isEmpty else {
            self.activeDocumentID = nil
            return
        }

        // Stay near the deleted document instead of jumping to the first item,
        // which is especially disruptive in a long sidebar.
        let fallbackIndex = min(removedIndex, documents.count - 1)
        self.activeDocumentID = documents[fallbackIndex].id
    }

    func appendToActiveBody(_ value: String) {
        mutateActive { document in
            document.body.append(value)
            document.updatedAt = Date()
            refreshAutomaticTitle(&document)
        }
    }

    func deleteBackwardFromActiveBody() {
        mutateActive { document in
            guard !document.body.isEmpty else { return }
            document.body.removeLast()
            document.updatedAt = Date()
            refreshAutomaticTitle(&document)
        }
    }

    func insertNewlineIntoActiveBody() {
        appendToActiveBody("\n")
    }

    @discardableResult
    func exportActiveDocument() -> Bool {
        guard let document = activeDocument,
              let data = document.body.data(using: .utf8) else { return false }

        let safeTitle = document.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (safeTitle.isEmpty ? "Kamihi Document" : safeTitle) + ".txt"
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
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 1,
                width: 1,
                height: 1
            )
        }
        presenter.present(activity, animated: true)
        return true
    }

    private func mutateActive(_ mutation: (inout Document) -> Void) {
        guard let activeDocumentID,
              let index = documents.firstIndex(where: { $0.id == activeDocumentID }) else { return }
        mutation(&documents[index])
    }

    private func refreshAutomaticTitle(_ document: inout Document) {
        guard document.title.hasPrefix("Untitled Document") else { return }
        guard let rawFirstLine = document.body.split(whereSeparator: \.isNewline).first else { return }
        let firstLine = String(rawFirstLine).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstLine.isEmpty else { return }
        document.title = String(firstLine.prefix(48))
    }

    private func seedInitialDocument() {
        let document = Document(title: "Untitled Document")
        documents = [document]
        activeDocumentID = document.id
    }

    private func saveDocuments() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func saveActiveSelection() {
        if let activeDocumentID {
            UserDefaults.standard.set(activeDocumentID.uuidString, forKey: activeDocumentStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeDocumentStorageKey)
        }
    }

    @discardableResult
    private func loadDocuments() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Document].self, from: data) else {
            return false
        }
        documents = saved
        return true
    }

    private func restoreActiveSelection() {
        guard let raw = UserDefaults.standard.string(forKey: activeDocumentStorageKey),
              let id = UUID(uuidString: raw),
              documents.contains(where: { $0.id == id }) else {
            activeDocumentID = documents.first?.id
            return
        }
        activeDocumentID = id
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
