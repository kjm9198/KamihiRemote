import SwiftUI
import UIKit

struct ControllerScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ZStack {
                ControllerPadView(session: session)
                    .padding(.leading, insets.leading + 8)
                    .padding(.trailing, insets.trailing + 8)
                    .padding(.top, insets.top + 4)
                    .padding(.bottom, insets.bottom + 4)
                if verticalSizeClass == .regular {
                    VStack {
                        Text("Rotate for controller")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                        Spacer()
                    }
                    .padding(.top, insets.top + 8)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onDisappear {
            session.sendController(.neutral)
        }
    }
}

struct ControllerPadView: UIViewRepresentable {
    let session: RemoteSession

    func makeUIView(context: Context) -> ControllerUIView {
        let view = ControllerUIView()
        view.session = session
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.isExclusiveTouch = false
        view.accessibilityViewIsModal = false
        return view
    }

    func updateUIView(_ uiView: ControllerUIView, context: Context) {
        uiView.session = session
        uiView.layout = session.preferences.controllerLayout
        uiView.deadZone = CGFloat(session.preferences.stickDeadZone)
        uiView.sensitivity = CGFloat(session.preferences.stickSensitivity)
        uiView.hapticsEnabled = session.preferences.controllerHaptics
        uiView.setNeedsLayout()
    }
}

final class ControllerUIView: UIView {
    weak var session: RemoteSession?
    var layout: ControllerLayout = .standard
    var deadZone: CGFloat = 0.12
    var sensitivity: CGFloat = 1
    var hapticsEnabled = true

    private var sequence: UInt32 = 0
    private var state = ControllerState()
    private var lastSent = ControllerState()
    private var identities: [ObjectIdentifier: Control] = [:]
    private var stickTouch: ObjectIdentifier?
    private var rightStickTouch: ObjectIdentifier?
    private var sendLink: CADisplayLink?
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    private enum Control {
        case stick
        case rightStick
        case button(ControllerButton)
        case shoulder(ControllerButton)
        case dpad
        case trigger(Bool)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        sendLink = CADisplayLink(target: self, selector: #selector(flush))
        sendLink?.add(to: .main, forMode: .common)
        impact.prepare()
    }

    required init?(coder: NSCoder) { nil }

    deinit { sendLink?.invalidate() }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        drawStick(in: leftStickFrame, value: CGPoint(x: CGFloat(state.leftX), y: CGFloat(state.leftY)), ctx: ctx)
        drawButtonCluster(ctx)
        drawShoulders(ctx)
        drawCenter(ctx)
        if layout == .fps || layout == .racing {
            drawStick(in: rightStickFrame, value: CGPoint(x: CGFloat(state.rightX), y: CGFloat(state.rightY)), ctx: ctx)
        }
    }

    private var leftStickFrame: CGRect {
        let side = min(bounds.height * 0.46, bounds.width * 0.28)
        return CGRect(x: bounds.minX + 24, y: bounds.midY - side / 2, width: side, height: side)
    }

    private var rightStickFrame: CGRect {
        let side = min(bounds.height * 0.32, bounds.width * 0.18)
        return CGRect(x: bounds.maxX - side - 36, y: bounds.maxY - side - 28, width: side, height: side)
    }

    private var buttonFrames: [(ControllerButton, CGRect)] {
        let r = min(bounds.height * 0.11, 46)
        let cx = bounds.maxX - 118
        let cy = bounds.midY - 6
        return [
            (.y, CGRect(x: cx - r / 2, y: cy - 78, width: r, height: r)),
            (.x, CGRect(x: cx - 78, y: cy - r / 2, width: r, height: r)),
            (.b, CGRect(x: cx + 34, y: cy - r / 2, width: r, height: r)),
            (.a, CGRect(x: cx - r / 2, y: cy + 34, width: r, height: r))
        ]
    }

    private var l1Frame: CGRect { CGRect(x: bounds.minX + 18, y: bounds.minY + 10, width: 86, height: 36) }
    private var r1Frame: CGRect { CGRect(x: bounds.maxX - 104, y: bounds.minY + 10, width: 86, height: 36) }
    private var l2Frame: CGRect { CGRect(x: bounds.minX + 18, y: bounds.minY + 52, width: 86, height: 28) }
    private var r2Frame: CGRect { CGRect(x: bounds.maxX - 104, y: bounds.minY + 52, width: 86, height: 28) }
    private var viewFrame: CGRect { CGRect(x: bounds.midX - 96, y: bounds.maxY - 54, width: 52, height: 36) }
    private var menuFrame: CGRect { CGRect(x: bounds.midX - 26, y: bounds.maxY - 54, width: 52, height: 36) }
    private var startFrame: CGRect { CGRect(x: bounds.midX + 44, y: bounds.maxY - 54, width: 52, height: 36) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { apply(touch, began: true) }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { apply(touch, began: false) }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { release(touch) }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { release(touch) }
        state = .neutral
        setNeedsDisplay()
    }

    private func apply(_ touch: UITouch, began: Bool) {
        let point = touch.location(in: self)
        let key = ObjectIdentifier(touch)
        if let existing = identities[key] {
            update(existing, at: point)
            return
        }
        guard began else { return }
        if leftStickFrame.contains(point) {
            identities[key] = .stick
            stickTouch = key
            update(.stick, at: point)
            return
        }
        if (layout == .fps || layout == .racing), rightStickFrame.contains(point) {
            identities[key] = .rightStick
            rightStickTouch = key
            update(.rightStick, at: point)
            return
        }
        if l1Frame.contains(point) { press(.l1, key: key); return }
        if r1Frame.contains(point) { press(.r1, key: key); return }
        if l2Frame.contains(point) { identities[key] = .trigger(true); state.leftTrigger = 1; return }
        if r2Frame.contains(point) { identities[key] = .trigger(false); state.rightTrigger = 1; return }
        if viewFrame.contains(point) { press(.view, key: key); return }
        if menuFrame.contains(point) { press(.menu, key: key); return }
        if startFrame.contains(point) { press(.start, key: key); return }
        for (button, frame) in buttonFrames where frame.contains(point) {
            press(button, key: key)
            return
        }
    }

    private func press(_ button: ControllerButton, key: ObjectIdentifier) {
        identities[key] = .button(button)
        if state.isDown(button) == false {
            buzz()
        }
        state.set(button, down: true)
    }

    private func update(_ control: Control, at point: CGPoint) {
        switch control {
        case .stick:
            let value = stickValue(point, in: leftStickFrame)
            state.leftX = Float(value.x)
            state.leftY = Float(value.y)
        case .rightStick:
            let value = stickValue(point, in: rightStickFrame)
            state.rightX = Float(value.x)
            state.rightY = Float(value.y)
        default:
            break
        }
    }

    private func release(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        guard let control = identities.removeValue(forKey: key) else { return }
        switch control {
        case .stick:
            state.leftX = 0
            state.leftY = 0
            stickTouch = nil
        case .rightStick:
            state.rightX = 0
            state.rightY = 0
            rightStickTouch = nil
        case .button(let button), .shoulder(let button):
            state.set(button, down: false)
        case .trigger(let left):
            if left { state.leftTrigger = 0 } else { state.rightTrigger = 0 }
        case .dpad:
            state.dpad = 0
        }
    }

    private func stickValue(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        var dx = (point.x - center.x) / (frame.width / 2)
        var dy = (point.y - center.y) / (frame.height / 2)
        let mag = hypot(dx, dy)
        if mag > 1 {
            dx /= mag
            dy /= mag
        }
        if mag < deadZone { return .zero }
        let scaled = (mag - deadZone) / (1 - deadZone)
        dx = dx / mag * scaled * sensitivity
        dy = dy / mag * scaled * sensitivity
        if mag >= 0.97 { buzzEdge() }
        return CGPoint(x: min(max(dx, -1), 1), y: min(max(dy, -1), 1))
    }

    @objc private func flush() {
        sequence &+= 1
        state.sequence = sequence
        state.timestamp = ProcessInfo.processInfo.systemUptime
        guard state != lastSent else { return }
        lastSent = state
        session?.sendController(state)
    }

    private var lastEdgeBuzz: TimeInterval = 0
    private func buzz() {
        guard hapticsEnabled else { return }
        impact.impactOccurred(intensity: 0.7)
    }
    private func buzzEdge() {
        guard hapticsEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEdgeBuzz > 0.4 else { return }
        lastEdgeBuzz = now
        impact.impactOccurred(intensity: 0.35)
    }

    private func drawStick(in frame: CGRect, value: CGPoint, ctx: CGContext) {
        UIColor.white.withAlphaComponent(0.12).setStroke()
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: frame.insetBy(dx: 6, dy: 6))
        let knob = CGSize(width: frame.width * 0.42, height: frame.height * 0.42)
        let x = frame.midX + value.x * (frame.width / 2 - knob.width / 2) - knob.width / 2
        let y = frame.midY + value.y * (frame.height / 2 - knob.height / 2) - knob.height / 2
        UIColor.white.withAlphaComponent(0.28).setFill()
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: x, y: y), size: knob))
    }

    private func drawButtonCluster(_ ctx: CGContext) {
        let labels: [ControllerButton: String] = [.a: "A", .b: "B", .x: "X", .y: "Y"]
        let colors: [ControllerButton: UIColor] = [
            .a: UIColor(red: 0.25, green: 0.78, blue: 0.82, alpha: 0.85),
            .b: UIColor(red: 0.92, green: 0.38, blue: 0.32, alpha: 0.85),
            .x: UIColor(red: 0.45, green: 0.42, blue: 0.95, alpha: 0.85),
            .y: UIColor(red: 0.95, green: 0.78, blue: 0.28, alpha: 0.85)
        ]
        for (button, frame) in buttonFrames {
            (state.isDown(button) ? colors[button]?.withAlphaComponent(1) : colors[button]?.withAlphaComponent(0.45))?.setFill()
            ctx.fillEllipse(in: frame)
            let text = labels[button] ?? ""
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2), withAttributes: attrs)
        }
    }

    private func drawShoulders(_ ctx: CGContext) {
        drawPill(l1Frame, title: "L1", down: state.isDown(.l1), ctx: ctx)
        drawPill(r1Frame, title: "R1", down: state.isDown(.r1), ctx: ctx)
        drawPill(l2Frame, title: "L2", down: state.leftTrigger > 0.2, ctx: ctx)
        drawPill(r2Frame, title: "R2", down: state.rightTrigger > 0.2, ctx: ctx)
    }

    private func drawCenter(_ ctx: CGContext) {
        drawPill(viewFrame, title: "View", down: state.isDown(.view), ctx: ctx)
        drawPill(menuFrame, title: "Menu", down: state.isDown(.menu), ctx: ctx)
        drawPill(startFrame, title: "Start", down: state.isDown(.start), ctx: ctx)
    }

    private func drawPill(_ frame: CGRect, title: String, down: Bool, ctx: CGContext) {
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 12)
        UIColor.white.withAlphaComponent(down ? 0.32 : 0.12).setFill()
        path.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let size = title.size(withAttributes: attrs)
        title.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2), withAttributes: attrs)
    }

    override var isAccessibilityElement: Bool {
        get { false }
        set {}
    }

    override var accessibilityElements: [Any]? {
        get {
            [
                labeled("Left stick", frame: leftStickFrame),
                labeled("A button", frame: buttonFrames.first { $0.0 == .a }?.1 ?? .zero),
                labeled("B button", frame: buttonFrames.first { $0.0 == .b }?.1 ?? .zero),
                labeled("X button", frame: buttonFrames.first { $0.0 == .x }?.1 ?? .zero),
                labeled("Y button", frame: buttonFrames.first { $0.0 == .y }?.1 ?? .zero),
                labeled("L1", frame: l1Frame),
                labeled("R1", frame: r1Frame),
                labeled("Start", frame: startFrame)
            ]
        }
        set {}
    }

    private func labeled(_ name: String, frame: CGRect) -> UIAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: self)
        element.accessibilityLabel = name
        element.accessibilityFrameInContainerSpace = frame
        element.accessibilityTraits = .button
        return element
    }
}
