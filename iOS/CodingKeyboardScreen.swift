import SwiftUI

/// Dedicated full-featured coding keyboard workspace designed specifically for mobile dev & vibe coding.
struct CodingKeyboardScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @FocusState private var isFieldFocused: Bool
    @State private var inputText = ""
    @State private var baseline = ""
    @State private var applyingRemote = false
    @State private var userIsEditing = false
    @State private var didApplySnapshot = false
    @State private var commandHeld = false
    @State private var optionHeld = false
    @State private var controlHeld = false
    @State private var shiftHeld = false
    @State private var activeCategory: KeyboardPaletteCategory = .syntax

    enum KeyboardPaletteCategory: String, CaseIterable, Identifiable {
        case syntax = "Symbols"
        case snippets = "Snippets"
        case nav = "Nav / Edit"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 8) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    focusedTextMirrorCard
                    liveInputSection
                    systemModifiersRow
                    paletteCategoryPicker
                    paletteContent
                    quickActionRow
                }
                .padding(.horizontal, KamihiUI.pad)
                .padding(.bottom, KamihiUI.pad)
            }
        }
        .onAppear {
            didApplySnapshot = false
            userIsEditing = false
            session.requestFocusedText()
        }
        .onChange(of: session.focusedTextStatus) { _, _ in
            applyFocusedSnapshotIfNeeded()
        }
        .onChange(of: session.focusedTextValue) { _, _ in
            applyFocusedSnapshotIfNeeded()
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("CODEKEY")
                    .font(KamihiUI.titleFont)
                    .tracking(KamihiUI.labelTracking)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            if !session.activeAppName.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(session.activeAppName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            Button {
                didApplySnapshot = false
                userIsEditing = false
                session.requestFocusedText()
                Haptics.touchTap()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.75))
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Refresh focused text")
        }
        .padding(.horizontal, KamihiUI.pad)
        .padding(.top, 4)
    }

    private var focusedTextMirrorCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MAC FOCUSED TEXT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.85))
                Spacer()
                Text(session.focusedTextStatus.rawValue)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if session.focusedTextValue.isEmpty {
                Text("No text selected or field not accessible")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                Text(session.focusedTextValue)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
    }

    private var liveInputSection: some View {
        HStack(spacing: 8) {
            TextField(liveInputPlaceholder, text: $inputText)
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.return)
                .onSubmit {
                    pressKey(code: 36)
                }
                .onChange(of: inputText) { _, newValue in
                    handleLiveEdit(newValue)
                }
                .font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: KamihiUI.radiusMedium))
                .foregroundStyle(.white)

            Button {
                isFieldFocused = false
                Haptics.touchTap()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish editing Mac text")
        }
    }

    private var liveInputPlaceholder: String {
        switch session.focusedTextStatus {
        case .value: return "Edit Mac text live…"
        case .secure: return "Secure field — typing only"
        case .unavailable: return "Type code or text to Mac…"
        }
    }

    private var systemModifiersRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                modifierButton(title: "⌘ cmd", active: commandHeld) { commandHeld.toggle() }
                modifierButton(title: "⌥ opt", active: optionHeld) { optionHeld.toggle() }
                modifierButton(title: "⌃ ctrl", active: controlHeld) { controlHeld.toggle() }
                modifierButton(title: "⇧ shift", active: shiftHeld) { shiftHeld.toggle() }
            }

            HStack(spacing: 6) {
                keyButton("esc", code: 53)
                keyButton("tab", code: 48)
                keyButton("space", code: 49)
                keyButton("⌫", code: 51)
                keyButton("⏎ return", code: 36)
            }

            HStack(spacing: 6) {
                keyButton("←", code: 123)
                keyButton("↓", code: 125)
                keyButton("↑", code: 126)
                keyButton("→", code: 124)
            }
        }
    }

    private var paletteCategoryPicker: some View {
        Picker("Category", selection: $activeCategory) {
            ForEach(KeyboardPaletteCategory.allCases) { cat in
                Text(cat.rawValue).tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var paletteContent: some View {
        switch activeCategory {
        case .syntax:
            syntaxMatrix
        case .snippets:
            snippetsGrid
        case .nav:
            editingShortcutsGrid
        }
    }

    private var syntaxMatrix: some View {
        VStack(spacing: 6) {
            let row1 = ["{ }", "( )", "[ ]", "< >", "=>", "->", "&&", "||"]
            let row2 = [";", ":", "\"", "'", "/", "\\", "`", "?"]
            let row3 = ["=", "+", "-", "*", "!", "%", "$", "_", "."]

            symbolRow(row1)
            symbolRow(row2)
            symbolRow(row3)
        }
    }

    private func symbolRow(_ symbols: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    sendSymbol(symbol)
                } label: {
                    Text(symbol)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                .accessibilityLabel(symbol)
            }
        }
    }

    private var snippetsGrid: some View {
        let snippets: [(title: String, code: String)] = [
            ("console.log", "console.log();"),
            ("print()", "print()"),
            ("git status", "git status\n"),
            ("npm dev", "npm run dev\n"),
            ("return", "return "),
            ("const", "const "),
            ("let", "let "),
            ("func", "func "),
            ("import", "import "),
            ("async/await", "async () => "),
            ("try/catch", "try {\n} catch (e) {\n}"),
            ("TODO", "// TODO: ")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(snippets, id: \.title) { snippet in
                Button {
                    session.send(.typeText(snippet.code))
                    Haptics.touchTap()
                } label: {
                    HStack {
                        Text(snippet.title)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.cyan.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusSmall))
            }
        }
    }

    private var editingShortcutsGrid: some View {
        let actions: [(title: String, shortcut: String, icon: String)] = [
            ("Copy", "cmd+c", "doc.on.doc"),
            ("Paste", "cmd+v", "doc.on.clipboard"),
            ("Cut", "cmd+x", "scissors"),
            ("Undo", "cmd+z", "arrow.uturn.backward"),
            ("Redo", "cmd+shift+z", "arrow.uturn.forward"),
            ("Select All", "cmd+a", "selection.pin.in.out"),
            ("Select Line", "selectline", "line.horizontal.3"),
            ("Save", "cmd+s", "square.and.arrow.down"),
            ("Find", "cmd+f", "magnifyingglass"),
            ("Format", "alt+shift+f", "wand.and.stars")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(actions, id: \.title) { item in
                Button {
                    session.send(.shortcut(item.shortcut))
                    Haptics.touchTap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.cyan)
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KamihiUI.radiusSmall))
            }
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 8) {
            Button {
                session.send(.shortcut("cmd+c"))
                Haptics.touchTap()
            } label: {
                Label("Copy ⌘C", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .foregroundStyle(.white)

            Button {
                session.send(.shortcut("cmd+v"))
                Haptics.touchTap()
            } label: {
                Label("Paste ⌘V", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .foregroundStyle(.white)
        }
    }

    private func modifierButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            Haptics.touchTap()
        }) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(active ? .cyan : .white.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(active ? Color.cyan.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(active ? Color.cyan.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
    }

    private func keyButton(_ title: String, code: UInt16) -> some View {
        Button {
            pressKey(code: code)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
    }

    private func pressKey(code: UInt16) {
        userIsEditing = true
        let flags = buildFlags()
        session.send(.keyDown(code: code, flags: flags))
        session.send(.keyUp(code: code, flags: flags))
        Haptics.touchTap()

        guard flags == 0 else { return }
        applyingRemote = true
        if code == 51, inputText.isEmpty == false {
            inputText.removeLast()
            baseline = inputText
        } else if code == 49 {
            inputText.append(" ")
            baseline = inputText
        }
        applyingRemote = false
    }

    private func sendSymbol(_ symbol: String) {
        if symbol == "{ }" {
            session.send(.typeText("{}"))
            session.send(.keyDown(code: 123, flags: 0)) // left arrow inside braces
            session.send(.keyUp(code: 123, flags: 0))
        } else if symbol == "( )" {
            session.send(.typeText("()"))
            session.send(.keyDown(code: 123, flags: 0))
            session.send(.keyUp(code: 123, flags: 0))
        } else if symbol == "[ ]" {
            session.send(.typeText("[]"))
            session.send(.keyDown(code: 123, flags: 0))
            session.send(.keyUp(code: 123, flags: 0))
        } else if symbol == "< >" {
            session.send(.typeText("<>"))
            session.send(.keyDown(code: 123, flags: 0))
            session.send(.keyUp(code: 123, flags: 0))
        } else {
            session.send(.typeText(symbol))
        }
        Haptics.touchTap()
    }

    private func applyFocusedSnapshotIfNeeded() {
        guard userIsEditing == false, didApplySnapshot == false else { return }
        applyingRemote = true
        defer { applyingRemote = false }

        switch session.focusedTextStatus {
        case .value:
            inputText = session.focusedTextValue
            baseline = session.focusedTextValue
            didApplySnapshot = true
        case .secure, .unavailable:
            inputText = ""
            baseline = ""
            didApplySnapshot = true
        }
    }

    private func handleLiveEdit(_ newValue: String) {
        guard applyingRemote == false else { return }
        userIsEditing = true
        if newValue == baseline { return }

        // Append-only edits are safe regardless of the focused app. Spaces are sent
        // as physical key events because some Mac text fields ignore typed spaces.
        if newValue.hasPrefix(baseline) {
            let suffix = String(newValue.dropFirst(baseline.count))
            for character in suffix {
                sendLiveCharacter(character)
            }
            baseline = newValue
            return
        }

        // Backspacing from the end is also safe and enables true remote deletion.
        if baseline.hasPrefix(newValue), baseline.count > newValue.count {
            let deletes = baseline.count - newValue.count
            for _ in 0..<deletes {
                session.send(.keyDown(code: 51, flags: 0))
                session.send(.keyUp(code: 51, flags: 0))
            }
            baseline = newValue
            return
        }

        // Do not emulate an arbitrary middle replacement by deleting the entire
        // focused value: in an editor that value may be a whole document. Restore
        // the safe baseline instead and let arrows/shortcuts handle cursor movement.
        applyingRemote = true
        inputText = baseline
        applyingRemote = false
        session.flashAction("CodeKey\nEdit the end of Mac text", success: false)
        Haptics.error()
    }

    private func sendLiveCharacter(_ character: Character) {
        if character == " " {
            session.send(.keyDown(code: 49, flags: 0))
            session.send(.keyUp(code: 49, flags: 0))
        } else {
            session.send(.typeText(String(character)))
        }
    }

    private func buildFlags() -> UInt64 {
        var flags: UInt64 = 0
        if commandHeld { flags |= (1 << 20) } // maskCommand
        if shiftHeld { flags |= (1 << 17) }   // maskShift
        if optionHeld { flags |= (1 << 19) }  // maskAlternate
        if controlHeld { flags |= (1 << 18) } // maskControl
        return flags
    }
}