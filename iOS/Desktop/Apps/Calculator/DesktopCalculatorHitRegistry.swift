import SwiftUI

/// Tracks Calculator controls in coordinates local to the Calculator app content.
/// The external display is passive, so the phone-controlled software cursor cannot
/// rely on UIKit touch delivery. SwiftUI reports the real rendered button frames
/// here and DesktopSession resolves pointer clicks against those frames.
@MainActor
final class DesktopCalculatorHitRegistry {
    static let shared = DesktopCalculatorHitRegistry()

    enum Target: Hashable {
        case toolbarClear
        case key(String)
    }

    struct Entry: Equatable {
        let target: Target
        let normalizedFrame: CGRect
    }

    private(set) var entries: [Entry] = []

    private init() {}

    func update(entries: [Entry]) {
        guard self.entries != entries else { return }
        self.entries = entries
    }

    func clear() {
        if !entries.isEmpty { entries.removeAll() }
    }

    func hitTest(at normalizedPoint: CGPoint) -> Target? {
        for entry in entries.reversed() {
            // A small expansion keeps software-pointer clicking forgiving without
            // allowing adjacent keypad keys to overlap materially.
            if entry.normalizedFrame.insetBy(dx: -0.0025, dy: -0.0025).contains(normalizedPoint) {
                return entry.target
            }
        }
        return nil
    }

    func perform(_ target: Target) {
        let calculator = DesktopCalculatorStore.shared
        switch target {
        case .toolbarClear:
            calculator.clear()
        case .key(let key):
            switch key {
            case "C": calculator.clear()
            case "⌫": calculator.backspace()
            case "=": calculator.evaluate()
            default: calculator.append(key)
            }
        }
    }
}

struct DesktopCalculatorHitPreference: Equatable {
    let target: DesktopCalculatorHitRegistry.Target
    let normalizedFrame: CGRect
}

struct DesktopCalculatorHitPreferenceKey: PreferenceKey {
    static var defaultValue: [DesktopCalculatorHitPreference] = []

    static func reduce(
        value: inout [DesktopCalculatorHitPreference],
        nextValue: () -> [DesktopCalculatorHitPreference]
    ) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Report this control's real rendered frame relative to the complete
    /// Calculator content view, normalized so resizing/iPad layouts remain valid.
    func desktopCalculatorHitTarget(
        _ target: DesktopCalculatorHitRegistry.Target,
        containerSize: CGSize
    ) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named("desktopCalculatorContent"))
                let normalized = containerSize.width > 0 && containerSize.height > 0
                    ? CGRect(
                        x: frame.minX / containerSize.width,
                        y: frame.minY / containerSize.height,
                        width: frame.width / containerSize.width,
                        height: frame.height / containerSize.height
                    )
                    : CGRect.zero

                Color.clear.preference(
                    key: DesktopCalculatorHitPreferenceKey.self,
                    value: [DesktopCalculatorHitPreference(target: target, normalizedFrame: normalized)]
                )
            }
        }
    }
}

@MainActor
extension DesktopSession {
    /// Resolve phone software-pointer clicks against the exact current Calculator
    /// layout. This deliberately runs only after the topmost Calculator window has
    /// been selected, so a background Calculator can never steal a click.
    func handleCalculatorClick(at point: CGPoint, in frame: CGRect) {
        let titleBarHeight = DesktopWindowChrome.titleBarHeight(for: frame)
        let contentTop = frame.minY + titleBarHeight
        let contentHeight = frame.maxY - contentTop
        guard frame.width > 0,
              contentHeight > 0,
              point.x >= frame.minX,
              point.x <= frame.maxX,
              point.y > contentTop,
              point.y <= frame.maxY else {
            wantsPhoneKeyboard = false
            return
        }

        wantsPhoneKeyboard = false
        let localPoint = CGPoint(
            x: (point.x - frame.minX) / frame.width,
            y: (point.y - contentTop) / contentHeight
        )

        guard let target = DesktopCalculatorHitRegistry.shared.hitTest(at: localPoint) else { return }
        DesktopCalculatorHitRegistry.shared.perform(target)
        if TrackpadSettings.shared.hapticsEnabled { Haptics.touchTap() }
    }
}
