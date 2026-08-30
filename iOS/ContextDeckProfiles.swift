import Foundation

enum ContextDeckCategory: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case vibe = "Vibe"
    case code = "VS Code"
    case xcode = "Xcode"
    case terminal = "Terminal"
    case web = "Browser"
    case general = "System"

    var id: String { rawValue }
}

struct ContextDeckItem: Identifiable, Equatable {
    var id: String
    var title: String
    var symbol: String
    var command: RemoteCommand
    var colorName: String = "cyan"
}

enum ContextDeckProfiles {
    static func items(for category: ContextDeckCategory, activeBundleID: String) -> [ContextDeckItem] {
        let resolved = (category == .auto) ? resolveAutoCategory(bundleID: activeBundleID) : category
        switch resolved {
        case .vibe:
            return vibeItems
        case .code:
            return vscodeItems
        case .xcode:
            return xcodeItems
        case .terminal:
            return terminalItems
        case .web:
            return browserItems
        case .general, .auto:
            return generalItems
        }
    }

    private static func resolveAutoCategory(bundleID: String) -> ContextDeckCategory {
        let lower = bundleID.lowercased()
        if lower.contains("cursor") {
            return .vibe
        }
        if lower.contains("vscode") || lower.contains("vscodium") || lower.contains("sublime") || lower.contains("zed") {
            return .code
        }
        if lower.contains("xcode") {
            return .xcode
        }
        if lower.contains("terminal") || lower.contains("iterm") || lower.contains("ghostty") || lower.contains("alacritty") || lower.contains("kitty") || lower.contains("warp") {
            return .terminal
        }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("arc") || lower.contains("firefox") || lower.contains("brave") || lower.contains("edge") {
            return .web
        }
        return .general
    }

    /// Cursor-focused controls for the fast prompt -> inspect -> run -> verify loop.
    /// Keeping this profile shortcut-only makes it safe to use without granting any
    /// new shell execution capability to the phone.
    static let vibeItems: [ContextDeckItem] = [
        ContextDeckItem(id: "vibe_agent", title: "Agent", symbol: "sparkles", command: .shortcut("cmd+i")),
        ContextDeckItem(id: "vibe_palette", title: "Palette", symbol: "command.square.fill", command: .shortcut("cmd+shift+p")),
        ContextDeckItem(id: "vibe_open", title: "Quick Open", symbol: "magnifyingglass", command: .shortcut("cmd+p")),
        ContextDeckItem(id: "vibe_terminal", title: "Terminal", symbol: "terminal.fill", command: .shortcut("ctrl+grave")),
        ContextDeckItem(id: "vibe_design", title: "Design Mode", symbol: "cursorarrow.motionlines", command: .shortcut("cmd+shift+d")),
        ContextDeckItem(id: "vibe_save", title: "Save", symbol: "square.and.arrow.down.fill", command: .shortcut("cmd+s")),
        ContextDeckItem(id: "vibe_run", title: "Run / Debug", symbol: "play.circle.fill", command: .shortcut("f5")),
        ContextDeckItem(id: "vibe_source", title: "Source Control", symbol: "arrow.triangle.branch", command: .shortcut("ctrl+shift+g"))
    ]

    static let vscodeItems: [ContextDeckItem] = [
        ContextDeckItem(id: "vsc_save", title: "Save", symbol: "square.and.arrow.down.fill", command: .shortcut("cmd+s")),
        ContextDeckItem(id: "vsc_palette", title: "Palette", symbol: "command.square.fill", command: .shortcut("cmd+shift+p")),
        ContextDeckItem(id: "vsc_term", title: "Terminal", symbol: "terminal.fill", command: .shortcut("ctrl+grave")),
        ContextDeckItem(id: "vsc_open", title: "Quick Open", symbol: "magnifyingglass", command: .shortcut("cmd+p")),
        ContextDeckItem(id: "vsc_sidebar", title: "Sidebar", symbol: "sidebar.left", command: .shortcut("cmd+b")),
        ContextDeckItem(id: "vsc_format", title: "Format", symbol: "wand.and.stars", command: .shortcut("alt+shift+f")),
        ContextDeckItem(id: "vsc_run", title: "Run", symbol: "play.circle.fill", command: .shortcut("f5")),
        ContextDeckItem(id: "vsc_git", title: "Source Control", symbol: "arrow.triangle.branch", command: .shortcut("ctrl+shift+g"))
    ]

    static let xcodeItems: [ContextDeckItem] = [
        ContextDeckItem(id: "xc_build", title: "Build", symbol: "hammer.fill", command: .shortcut("cmd+b")),
        ContextDeckItem(id: "xc_run", title: "Run", symbol: "play.fill", command: .shortcut("cmd+r")),
        ContextDeckItem(id: "xc_stop", title: "Stop", symbol: "stop.fill", command: .shortcut("cmd+period")),
        ContextDeckItem(id: "xc_clean", title: "Clean Build", symbol: "trash.fill", command: .shortcut("cmd+shift+k")),
        ContextDeckItem(id: "xc_canvas", title: "Canvas Preview", symbol: "macwindow.badge.plus", command: .shortcut("alt+cmd+p")),
        ContextDeckItem(id: "xc_test", title: "Run Tests", symbol: "checkmark.seal.fill", command: .shortcut("cmd+u")),
        ContextDeckItem(id: "xc_jump", title: "Jump Def", symbol: "arrowshape.turn.up.right.fill", command: .shortcut("ctrl+cmd+j")),
        ContextDeckItem(id: "xc_find", title: "Workspace Find", symbol: "magnifyingglass.circle.fill", command: .shortcut("cmd+shift+f"))
    ]

    static let terminalItems: [ContextDeckItem] = [
        ContextDeckItem(id: "term_ctrl_c", title: "Interrupt ^C", symbol: "xmark.octagon.fill", command: .shortcut("ctrl+c")),
        ContextDeckItem(id: "term_clear", title: "Clear ⌘K", symbol: "paintbrush.fill", command: .shortcut("cmd+k")),
        ContextDeckItem(id: "term_prev", title: "Prev Cmd ↑", symbol: "arrow.up.circle.fill", command: .shortcut("up")),
        ContextDeckItem(id: "term_npm", title: "npm run dev", symbol: "play.rectangle.fill", command: .typeText("npm run dev\n")),
        ContextDeckItem(id: "term_status", title: "git status", symbol: "arrow.triangle.branch", command: .typeText("git status\n")),
        ContextDeckItem(id: "term_diff", title: "git diff", symbol: "doc.text.magnifyingglass", command: .typeText("git diff\n")),
        ContextDeckItem(id: "term_push", title: "git push", symbol: "arrow.up.to.line.compact", command: .typeText("git push\n")),
        ContextDeckItem(id: "term_pull", title: "git pull", symbol: "arrow.down.to.line.compact", command: .typeText("git pull\n"))
    ]

    static let browserItems: [ContextDeckItem] = [
        ContextDeckItem(id: "web_newtab", title: "New Tab", symbol: "plus.rectangle.on.rectangle", command: .shortcut("cmd+t")),
        ContextDeckItem(id: "web_closetab", title: "Close Tab", symbol: "xmark.rectangle", command: .shortcut("cmd+w")),
        ContextDeckItem(id: "web_nexttab", title: "Next Tab", symbol: "chevron.right.square.fill", command: .shortcut("cmd+alt+right")),
        ContextDeckItem(id: "web_prevtab", title: "Prev Tab", symbol: "chevron.left.square.fill", command: .shortcut("cmd+alt+left")),
        ContextDeckItem(id: "web_inspect", title: "DevTools", symbol: "chevron.left.forwardslash.chevron.right", command: .shortcut("cmd+alt+i")),
        ContextDeckItem(id: "web_reload", title: "Hard Reload", symbol: "arrow.clockwise.circle.fill", command: .shortcut("cmd+shift+r")),
        ContextDeckItem(id: "web_address", title: "Address Bar", symbol: "link", command: .shortcut("cmd+l")),
        ContextDeckItem(id: "web_dup", title: "Duplicate Tab", symbol: "doc.on.doc.fill", command: .shortcut("cmd+l"))
    ]

    static let generalItems: [ContextDeckItem] = [
        ContextDeckItem(id: "gen_copy", title: "Copy", symbol: "doc.on.doc", command: .shortcut("cmd+c")),
        ContextDeckItem(id: "gen_paste", title: "Paste", symbol: "doc.on.clipboard", command: .shortcut("cmd+v")),
        ContextDeckItem(id: "gen_undo", title: "Undo", symbol: "arrow.uturn.backward", command: .shortcut("cmd+z")),
        ContextDeckItem(id: "gen_desk_left", title: "Desktop ←", symbol: "arrow.left.square.fill", command: .system(.previousDesktop)),
        ContextDeckItem(id: "gen_desk_right", title: "Desktop →", symbol: "arrow.right.square.fill", command: .system(.nextDesktop)),
        ContextDeckItem(id: "gen_mission", title: "Mission Control", symbol: "rectangle.3.group.fill", command: .system(.missionControl)),
        ContextDeckItem(id: "gen_expose", title: "App Exposé", symbol: "square.grid.2x2.fill", command: .system(.appExpose)),
        ContextDeckItem(id: "gen_screenshot", title: "Screenshot", symbol: "camera.viewfinder", command: .shortcut("cmd+shift+4"))
    ]
}
