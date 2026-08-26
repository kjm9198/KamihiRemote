import SwiftUI

struct VibeMacro: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var prompt: String
    var symbol: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        symbol: String = "bolt.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.symbol = symbol
        self.createdAt = createdAt
    }
}

enum VibeMacroStore {
    private static let key = "personalVibeMacrosV1"
    private static let limit = 24

    static func load() -> [VibeMacro] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VibeMacro].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(limit))
    }

    static func save(_ macros: [VibeMacro]) {
        let clean = Array(macros.prefix(limit))
        guard let data = try? JSONEncoder().encode(clean) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// User-owned prompt shortcuts. A macro only fills the composer; it never sends automatically.
/// Keep the primary Vibe surface quiet: saved macros live behind one compact, accessible menu.
struct VibeMacroBar: View {
    @Binding var promptText: String
    @Binding var vibeStatus: String

    @State private var macros: [VibeMacro] = VibeMacroStore.load()
    @State private var showsManager = false

    var body: some View {
        HStack(spacing: 6) {
            if macros.isEmpty {
                Button {
                    showsManager = true
                    Haptics.touchTap()
                } label: {
                    Label("Add Macro", systemImage: "plus.circle.fill")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(Rectangle())
                .accessibilityLabel("Add personal Vibe macro")
            } else {
                Menu {
                    ForEach(macros) { macro in
                        Button {
                            use(macro)
                        } label: {
                            Label(macro.title, systemImage: macro.symbol)
                        }
                    }

                    Divider()

                    Button {
                        showsManager = true
                        Haptics.touchTap()
                    } label: {
                        Label("Manage Macros…", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("Macros")
                        Text("\(macros.count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.mint)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(Rectangle())
                .accessibilityLabel("Personal Vibe macros, \(macros.count) saved")
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showsManager) {
            VibeMacroManagerSheet(macros: $macros)
        }
        .onAppear {
            macros = VibeMacroStore.load()
        }
        .onChange(of: macros) { _, newValue in
            VibeMacroStore.save(newValue)
        }
    }

    private func use(_ macro: VibeMacro) {
        promptText = macro.prompt
        vibeStatus = "\(macro.title) ready — edit or send"
        Haptics.touchTap()
    }
}

private struct VibeMacroManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var macros: [VibeMacro]

    @State private var editingID: UUID?
    @State private var title = ""
    @State private var prompt = ""
    @State private var selectedSymbol = "bolt.fill"

    private let symbols = [
        "bolt.fill",
        "wrench.and.screwdriver.fill",
        "checkmark.seal.fill",
        "wand.and.sparkles",
        "paperplane.fill",
        "ladybug.fill",
        "iphone.gen3",
        "server.rack",
        "shippingbox.fill",
        "brain.head.profile"
    ]

    var body: some View {
        NavigationStack {
            List {
                if macros.isEmpty == false {
                    Section("Your Macros") {
                        ForEach(macros) { macro in
                            Button {
                                beginEditing(macro)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: macro.symbol)
                                        .foregroundStyle(.mint)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(macro.title)
                                            .foregroundStyle(.primary)
                                        Text(macro.prompt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            macros.remove(atOffsets: offsets)
                            VibeMacroStore.save(macros)
                        }
                        .onMove { source, destination in
                            macros.move(fromOffsets: source, toOffset: destination)
                            VibeMacroStore.save(macros)
                        }
                    }
                }

                Section {
                    TextField("Short name, e.g. Mobile polish", text: $title)

                    TextField(
                        "Instruction to reuse…",
                        text: $prompt,
                        axis: .vertical
                    )
                    .lineLimit(4...10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(symbols, id: \.self) { symbol in
                                Button {
                                    selectedSymbol = symbol
                                    Haptics.touchTap()
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                        .foregroundStyle(selectedSymbol == symbol ? .mint : .secondary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            selectedSymbol == symbol
                                                ? Color.mint.opacity(0.14)
                                                : Color.clear,
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(symbol)
                            }
                        }
                    }

                    Button {
                        saveMacro()
                    } label: {
                        Label(
                            editingID == nil ? "Save Macro" : "Update Macro",
                            systemImage: editingID == nil ? "plus.circle.fill" : "checkmark.circle.fill"
                        )
                    }
                    .disabled(cleanTitle.isEmpty || cleanPrompt.isEmpty)

                    if editingID != nil {
                        Button("Cancel Editing", role: .cancel) {
                            resetEditor()
                        }
                    }
                } header: {
                    Text(editingID == nil ? "New Macro" : "Edit Macro")
                } footer: {
                    Text("Macros are stored only on this iPhone. Choosing one fills the Vibe composer so you can review or modify it before sending.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personal Vibe Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        VibeMacroStore.save(macros)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginEditing(_ macro: VibeMacro) {
        editingID = macro.id
        title = macro.title
        prompt = macro.prompt
        selectedSymbol = macro.symbol
        Haptics.touchTap()
    }

    private func saveMacro() {
        guard cleanTitle.isEmpty == false, cleanPrompt.isEmpty == false else { return }

        if let editingID,
           let index = macros.firstIndex(where: { $0.id == editingID }) {
            macros[index].title = cleanTitle
            macros[index].prompt = cleanPrompt
            macros[index].symbol = selectedSymbol
        } else {
            macros.append(
                VibeMacro(
                    title: cleanTitle,
                    prompt: cleanPrompt,
                    symbol: selectedSymbol
                )
            )
        }

        VibeMacroStore.save(macros)
        resetEditor()
        Haptics.gesture()
    }

    private func resetEditor() {
        editingID = nil
        title = ""
        prompt = ""
        selectedSymbol = "bolt.fill"
    }
}
