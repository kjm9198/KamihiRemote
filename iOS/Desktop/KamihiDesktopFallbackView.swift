import SwiftUI

/// Compatibility wrapper for older Desktop-only view compositions that still
/// need a phone-side fallback when no external display is connected.
///
/// Kamihi Remote is retired: this deliberately routes to the Kamihi Desktop
/// external-display guidance instead of restoring any host/pairing shell.
struct KamihiAppShell: View {
    var body: some View {
        NoDisplayConnectedView()
    }
}
