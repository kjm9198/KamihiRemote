import SwiftUI
import UIKit

struct ControllerScreen: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var showsGameSessions = false
    @State private var gameSessions: [GameSessionProfile] = GameSessionStore.load()
    @AppStorage("selectedGameSessionID") private var selectedGameSessionID = ""

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height > geo.size.width * 1.05
            VStack(spacing: 4) {
                // Top control bar: Profile Picker & Quick Navigation
                HStack(spacing: 8) {
                    Picker("Profile", selection: Binding(
                        get: { session.preferences.controllerProfile },
                        set: { newProfile in
                            selectedGameSessionID = ""
                            session.preferences.controllerProfile = newProfile
                            let newMapping = ControllerMapping.defaultFor(profile: newProfile)
                            session.preferences.controllerMapping = newMapping
                            session.send(.syncControllerMapping(newMapping))
                            Haptics.click()
                        }
                    )) {
                        Text("🎮 Gaming (WASD)").tag(ControllerProfile.gaming)
                        Text("💻 Mac Control").tag(ControllerProfile.mac)
                        Text("📊 Media").tag(ControllerProfile.presentation)
                    }
                    .pickerStyle(.segmented)

                    Spacer(minLength: 4)

                    Button {
                        session.sendController(.neutral)
                        gameSessions = GameSessionStore.load()
                        showsGameSessions = true
                        Haptics.touchTap()
                    } label: {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(selectedGameSessionID.isEmpty ? .white : .cyan)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Game Sessions")

                    Menu {
                        Button("Remote") { session.leaveController(to: .trackpad) }
                        Button("Deck") { session.leaveController(to: .deck) }
                        Divider()
                        Button("Game Sessions") {
                            session.sendController(.neutral)
                            gameSessions = GameSessionStore.load()
                            showsGameSessions = true
                        }
                        Button("Keyboard") {
                            session.sendController(.neutral)
                            session.showsKeyboard = true
                        }
                        Button("Settings") {
                            session.sendController(.neutral)
                            session.showsSettings = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(.white)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                ControllerPadView(session: session, compact: compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .sheet(isPresented: $showsGameSessions) {
            GameSessionManagerSheet(
                profiles: $gameSessions,
                selectedProfileID: $selectedGameSessionID
            )
            .environmentObject(session)
        }
        .onDisappear {
            session.sendController(.neutral)
        }
    }
}

struct ControllerPadView: UIViewRepresentable {
    let session: RemoteSession
    var compact: Bool = false

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
        uiView.compactLayout = compact
        uiView.layout = session.preferences.controllerLayout
        uiView.deadZone = CGFloat(session.preferences.stickDeadZone)
        uiView.sensitivity = CGFloat(session.preferences.stickSensitivity)
        uiView.hapticsEnabled = session.preferences.controllerHaptics
        uiView.setNeedsLayout()
    }
}

final class ControllerUIView: UIView {
    weak var session: RemoteSession?
    var compactLayout = false
    var layout: ControllerLayout = .fps
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
        drawStick(in: leftStickFrame, value: CGPoint(x: CGFloat(state.leftX), y: CGFloat(state.leftY)), label: "L-STICK (WASD)", ctx: ctx)
        drawButtonCluster(ctx)
        drawShoulders(ctx)
        drawCenter(ctx)
        drawStick(in: rightStickFrame, value: CGPoint(x: CGFloat(state.rightX), y: CGFloat(state.rightY)), label: "R-STICK (LOOK)", ctx: ctx)
    }

    /// Usable drawing area — respects safe area and keeps controls on-screen.
    private var layoutBounds: CGRect {
        let inset = safeAreaInsets
        let pad: CGFloat = compactLayout ? 6 : 10
        return bounds
            .inset(by: inset)
            .insetBy(dx: pad, dy: pad)
    }

    private var leftControlsRegion: CGRect {
        let b = layoutBounds
        if compactLayout {
            return CGRect(x: b.minX, y: b.midY - b.height * 0.22,
                          width: b.width * 0.42, height: b.height * 0.44)
        }
        return CGRect(x: b.minX, y: b.minY + b.height * 0.16,
                      width: b.width * 0.36, height: b.height * 0.58)
    }

    private var rightControlsRegion: CGRect {
        let b = layoutBounds
        if compactLayout {
            return CGRect(x: b.maxX - b.width * 0.42, y: b.midY - b.height * 0.22,
                          width: b.width * 0.42, height: b.height * 0.44)
        }
        return CGRect(x: b.maxX - b.width * 0.36, y: b.minY + b.height * 0.16,
                      width: b.width * 0.36, height: b.height * 0.58)
    }

    private var shoulderRegion: CGRect {
        let b = layoutBounds
        return CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height * (compactLayout ? 0.18 : 0.20))
    }

    private var centerRegion: CGRect {
        let b = layoutBounds
        let h = compactLayout ? b.height * 0.14 : b.height * 0.16
        return CGRect(x: b.midX - b.width * 0.20, y: b.maxY - h - 4,
                      width: b.width * 0.40, height: h)
    }

    private var leftStickFrame: CGRect {
        let maxSide = compactLayout ? 100.0 : 150.0
        let minSide = compactLayout ? 72.0 : 100.0
        let side = min(max(minSide, leftControlsRegion.width * 0.78), maxSide)
        let x = leftControlsRegion.midX - side / 2
        let y = leftControlsRegion.midY - side / 2
        return clampFrame(CGRect(x: x, y: y, width: side, height: side))
    }

    private var rightStickFrame: CGRect {
        let maxSide = compactLayout ? 96.0 : 130.0
        let minSide = compactLayout ? 68.0 : 90.0
        let side = min(max(minSide, rightControlsRegion.width * (compactLayout ? 0.44 : 0.46)), maxSide)
        let x = compactLayout
            ? (rightControlsRegion.midX - side / 2)
            : (rightControlsRegion.minX + 12)
        let y = rightControlsRegion.maxY - side - (compactLayout ? 4 : 8)
        let frame = CGRect(x: x, y: y, width: side, height: side)
        return clampFrame(frame)
    }

    private var buttonFrames: [(ControllerButton, CGRect)] {
        let r = min(max(compactLayout ? 32 : 38, rightControlsRegion.width * (compactLayout ? 0.22 : 0.20)), compactLayout ? 42 : 48)
        let gap = r * 0.84
        let cx = compactLayout
            ? rightControlsRegion.midX
            : (rightControlsRegion.maxX - r * 1.7)
        let cy = compactLayout
            ? (rightControlsRegion.minY + rightControlsRegion.height * 0.30)
            : (rightControlsRegion.minY + r * 1.55)
        return [
            (.y, clampFrame(CGRect(x: cx - r / 2, y: cy - gap - r / 2, width: r, height: r))),
            (.x, clampFrame(CGRect(x: cx - gap - r / 2, y: cy - r / 2, width: r, height: r))),
            (.b, clampFrame(CGRect(x: cx + gap - r / 2, y: cy - r / 2, width: r, height: r))),
            (.a, clampFrame(CGRect(x: cx - r / 2, y: cy + gap - r / 2, width: r, height: r)))
        ]
    }

    private var l1Frame: CGRect {
        let w = min(shoulderRegion.width * 0.20, 88)
        return clampFrame(CGRect(x: shoulderRegion.minX + 4, y: shoulderRegion.minY + 4, width: w, height: 32))
    }
    private var r1Frame: CGRect {
        let w = min(shoulderRegion.width * 0.20, 88)
        return clampFrame(CGRect(x: shoulderRegion.maxX - w - 4, y: shoulderRegion.minY + 4, width: w, height: 32))
    }
    private var l2Frame: CGRect {
        clampFrame(CGRect(x: l1Frame.minX, y: l1Frame.maxY + 4, width: l1Frame.width, height: 24))
    }
    private var r2Frame: CGRect {
        clampFrame(CGRect(x: r1Frame.minX, y: r1Frame.maxY + 4, width: r1Frame.width, height: 24))
    }
    private var viewFrame: CGRect {
        clampFrame(CGRect(x: centerRegion.minX, y: centerRegion.midY - 16, width: 46, height: 32))
    }
    private var menuFrame: CGRect {
        clampFrame(CGRect(x: centerRegion.midX - 23, y: centerRegion.midY - 16, width: 46, height: 32))
    }
    private var startFrame: CGRect {
        clampFrame(CGRect(x: centerRegion.maxX - 46, y: centerRegion.midY - 16, width: 46, height: 32))
    }

    private func clampFrame(_ frame: CGRect) -> CGRect {
        layoutBounds.intersection(frame)
    }

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
        if leftStickFrame.insetBy(dx: -10, dy: -10).contains(point) {
            identities[key] = .stick
            stickTouch = key
            update(.stick, at: point)
            return
        }
        if rightStickFrame.insetBy(dx: -10, dy: -10).contains(point) {
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
        for (button, frame) in buttonFrames where frame.insetBy(dx: -6, dy: -6).contains(point) {
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
        guard frame.width > 1, frame.height > 1 else { return .zero }
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

    private func drawStick(in frame: CGRect, value: CGPoint, label: String, ctx: CGContext) {
        guard frame.width > 4, frame.height > 4 else { return }
        UIColor.white.withAlphaComponent(0.14).setStroke()
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: frame.insetBy(dx: 4, dy: 4))
        let knob = CGSize(width: frame.width * 0.42, height: frame.height * 0.42)
        let x = frame.midX + value.x * (frame.width / 2 - knob.width / 2) - knob.width / 2
        let y = frame.midY + value.y * (frame.height / 2 - knob.height / 2) - knob.height / 2
        UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 0.45).setFill()
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: x, y: y), size: knob))
        UIColor.white.withAlphaComponent(0.40).setStroke()
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: x, y: y), size: knob))
    }

    private func drawButtonCluster(_ ctx: CGContext) {
        let labels: [ControllerButton: String] = [.a: "A", .b: "B", .x: "X", .y: "Y"]
        let colors: [ControllerButton: UIColor] = [
            .a: UIColor(red: 0.25, green: 0.78, blue: 0.82, alpha: 0.85),
            .b: UIColor(red: 0.92, green: 0.38, blue: 0.32, alpha: 0.85),
            .x: UIColor(red: 0.45, green: 0.42, blue: 0.95, alpha: 0.85),
            .y: UIColor(red: 0.95, green: 0.78, blue: 0.28, alpha: 0.85)
        ]
        for (button, frame) in buttonFrames where frame.width > 4 {
            (state.isDown(button) ? colors[button]?.withAlphaComponent(1) : colors[button]?.withAlphaComponent(0.45))?.setFill()
            ctx.fillEllipse(in: frame)
            let text = labels[button] ?? ""
            let fontSize: CGFloat = compactLayout ? 13 : 16
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
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
        guard frame.width > 4, frame.height > 4 else { return }
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 10)
        UIColor.white.withAlphaComponent(down ? 0.32 : 0.12).setFill()
        path.fill()
        let fontSize: CGFloat = compactLayout ? 10 : 12
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
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
