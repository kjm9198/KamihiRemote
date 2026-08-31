import SwiftUI

/// Coordinates the top-level product mode navigation in Kamihi Remote.
@MainActor
public final class AppModeRouter: ObservableObject {
    @Published public var currentMode: AppMode
    @Published public var isDesktopLabActive: Bool
    @Published public var showsSettings: Bool = false

    public init() {
        let initial = AppMode.initialModeFromArguments()
        self.currentMode = initial.mode
        self.isDesktopLabActive = initial.isLab
    }

    public func selectMode(_ mode: AppMode) {
        withAnimation(KamihiTheme.Animation.standard) {
            self.currentMode = mode
            self.isDesktopLabActive = false
        }
    }

    public func returnToChooser() {
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
