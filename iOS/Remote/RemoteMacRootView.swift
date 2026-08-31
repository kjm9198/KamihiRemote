import SwiftUI

/// Root view for the Remote for Mac product experience.
/// Dedicated entirely to Mac control (trackpad, keyboard, shortcut deck, Vibe hub, connection diagnostics).
struct RemoteMacRootView: View {
    @EnvironmentObject private var router: AppModeRouter
    @EnvironmentObject private var session: RemoteSession

    var body: some View {
        ZStack(alignment: .top) {
            RootView()
                .environmentObject(session)

            // Minimal navigation overlay with Back button to Mode Chooser
            HStack {
                Button {
                    router.returnToChooser()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Modes")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Return to Mode Chooser")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .allowsHitTesting(true)
        }
    }
}
