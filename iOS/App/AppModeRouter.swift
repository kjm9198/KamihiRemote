import SwiftUI

/// Coordinates the single Kamihi Desktop and Desktop Lab. After the user enters
/// Desktop once, normal launches return directly to that desktop controller state
/// instead of repeatedly presenting an artificial mode chooser.
@MainActor
public final class AppModeRouter: ObservableObject {
    @Published public var currentMode: AppMode
    @Published public var isDesktopLabActive: Bool
    @Published public var showsSettings: Bool = false

    private let defaults = UserDefaults.standard
    private let enteredDesktopKey = "kamihi.desktop.hasEnteredPersistentDesktop.v1"

    public init() {
        let initial = AppMode.initialModeFromArguments()
        let hasExplicitLaunchArgument = initial.mode != .none || initial.isLab
        if hasExplicitLaunchArgument {
            self.currentMode = initial.mode
            self.isDesktopLabActive = initial.isLab
        } else if defaults.bool(forKey: enteredDesktopKey) {
            self.currentMode = .externalDesktop
            self.isDesktopLabActive = false
        } else {
            self.currentMode = .none
            self.isDesktopLabActive = false
        }
    }

    public func selectMode(_ mode: AppMode) {
        if mode == .externalDesktop {
            defaults.set(true, forKey: enteredDesktopKey)
        }
        withAnimation(KamihiTheme.Animation.standard) {
            self.currentMode = mode
            self.isDesktopLabActive = false
        }
    }

    /// Kept as an explicit escape hatch for support/debugging. A normal cable
    /// disconnect never calls this, so the OS remains persistent across reconnects.
    public func returnToChooser() {
        defaults.set(false, forKey: enteredDesktopKey)
        withAnimation(KamihiTheme.Animation.standard) {
            self.currentMode = .none
            self.isDesktopLabActive = false
        }
    }

    public func startDesktopLab() {
        withAnimation(KamihiTheme.Animation.standard) {
            self.currentMode = .externalDesktop
            self.isDesktopLabActive = true
        }
    }

    public func exitDesktopLab() {
        withAnimation(KamihiTheme.Animation.standard) {
            self.isDesktopLabActive = false
        }
    }
}
