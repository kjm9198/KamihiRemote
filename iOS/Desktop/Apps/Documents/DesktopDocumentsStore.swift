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
        didSet { save() }
    }
    @Published private(set) var activeDocumentID: UUID? {
        didSet { save() }
    }

    private let storageKey = "kamihi.desktop.documents.v1"

    private init() {
        load()
        if documents.isEmpty {
            let document = Document(title: "Untitled Document")
            documents = [document]
            activeDocumentID = document.id
        } else if activeDocumentID == nil {
            activeDocumentID = documents.first?.id
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
        guard let activeDocumentID else { return }
        documents.removeAll { $0.id == activeDocumentID }
        if documents.isEmpty {
            let replacement = Document(title: "Untitled Document")
            documents = [replacement]
            self.activeDocumentID = replacement.id
        } else {
            self.activeDocumentID = documents.first?.id
        }
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

    /// Export the active document as a plain-text file through the standard iOS
    /// share sheet. This gives the user a Files/Drive/AirDrop path without Kamihi
    /// taking broad filesystem access or silently uploading the document.
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

    private func save() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let activeDocumentID {
            UserDefaults.standard.set(activeDocumentID.uuidString, forKey: storageKey + ".active")
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey + ".active")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Document].self, from: data) {
            documents = saved
        }
        if let raw = UserDefaults.standard.string(forKey: storageKey + ".active"),
           let id = UUID(uuidString: raw),
           documents.contains(where: { $0.id == id }) {
            activeDocumentID = id
        }
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
