import AppKit
import CoreGraphics

enum LaserOverlay {
    private static var panel: NSPanel?
    private static var dot: NSView?

    static func setVisible(_ visible: Bool) {
        DispatchQueue.main.async {
            if visible {
                ensure()
                panel?.orderFrontRegardless()
            } else {
                panel?.orderOut(nil)
            }
        }
    }

    static func move(normalizedX: Double, normalizedY: Double) {
        DispatchQueue.main.async {
            ensure()
            guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            let frame = screen.frame
            let x = frame.minX + CGFloat(min(max(normalizedX, 0), 1)) * frame.width
            let y = frame.maxY - CGFloat(min(max(normalizedY, 0), 1)) * frame.height
            panel.setFrameOrigin(CGPoint(x: x - 14, y: y - 14))
            panel.orderFrontRegardless()
        }
    }

    private static func ensure() {
        if panel != nil { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 28, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        let dot = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 14
        dot.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.88).cgColor
        panel.contentView = dot
        self.panel = panel
        self.dot = dot
    }
}
