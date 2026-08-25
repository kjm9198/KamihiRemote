import QuartzCore
import UIKit

final class TouchInputEngine: NSObject, ObservableObject {
    @Published private(set) var animation = TouchAnimationState.idle
    @Published private(set) var stats = TouchPipelineStats()
    @Published private(set) var debug = GestureDebug()
    @Published private(set) var canvasSize = CGSize(width: 390, height: 640)
    @Published var precisionActive = false {
        didSet { gesture.precisionActive = precisionActive }
    }

    let gesture = GestureEngine()
    var preferences: AppPreferences {
        didSet { gesture.preferences = preferences }
    }

    private let senderBox = SenderBox()
    private var latestAnimation = TouchAnimationState.idle
    private var displayLink: CADisplayLink?
    private var movesThisSecond = 0
    private var secondTimer: Timer?
    private var lastMomentumTime: TimeInterval = 0
    private var lastSize = CGSize(width: 390, height: 640)

    init(sender: CommandSending? = nil) {
        self.preferences = AppPreferences.load()
        super.init()
        senderBox.sender = sender
        gesture.preferences = preferences
        startDisplayLink()
        startSecondTimer()
    }

    func attach(_ sender: CommandSending) {
        senderBox.sender = sender
    }

    deinit {
        displayLink?.invalidate()
        secondTimer?.invalidate()
    }

    func syncConnection(_ isConnected: Bool) {
        gesture.isConnected = isConnected
        var next = latestAnimation
        next.isConnected = isConnected
        latestAnimation = next
    }

    func handle(samples: [FingerSample], timestamp: TimeInterval, phase: UITouch.Phase, in size: CGSize) {
        handle(changed: samples, active: samples, timestamp: timestamp, phase: phase, in: size)
    }

    func handle(changed: [FingerSample], active: [FingerSample], timestamp: TimeInterval, phase: UITouch.Phase, in size: CGSize) {
        lastSize = size
        if size.width > 1, size.height > 1, canvasSize != size {
            canvasSize = size
        }
        if phase == .began {
            stats.touchActive = true
            stats.touchCount += 1
        }
        let output = gesture.handle(changed: changed, active: active, timestamp: timestamp, phase: phase, in: size)
        emit(output)
        if phase == .ended || phase == .cancelled {
            if active.isEmpty || gesture.mode == .idle {
                stats.touchActive = false
                stats.dx = 0
                stats.dy = 0
            }
        }
        if let point = active.first?.point ?? changed.first?.point {
            stats.x = point.x
            stats.y = point.y
        }
        stats.activeFingers = active.count
    }

    func noteCanvasSize(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        lastSize = size
        if canvasSize != size {
            canvasSize = size
            var next = latestAnimation
            next.trackpadSize = size
            latestAnimation = next
        }
    }

    func handleCancelled(in size: CGSize) {
        emit(gesture.cancel(size: size))
        stats.touchActive = false
        stats.dx = 0
        stats.dy = 0
        stats.activeFingers = 0
    }

    func orientationChanged(in size: CGSize) {
        handleCancelled(in: size)
    }

    private func emit(_ output: GestureOutput) {
        latestAnimation = output.animation
        debug = output.debug
        for command in output.commands {
            senderBox.sender?.send(command)
            stats.packetsSent += 1
            if case .move(let dx, let dy) = command {
                stats.dx = dx
                stats.dy = dy
                stats.moveSent += 1
                movesThisSecond += 1
            }
        }
    }

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(flushAnimation))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func startSecondTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.stats.movePerSecond = self.movesThisSecond
            self.movesThisSecond = 0
        }
        RunLoop.main.add(timer, forMode: .common)
        secondTimer = timer
    }

    @objc private func flushAnimation() {
        let now = CACurrentMediaTime()
        if lastMomentumTime == 0 { lastMomentumTime = now }
        let dt = now - lastMomentumTime
        lastMomentumTime = now
        if gesture.mode == .idle {
            let extra = gesture.tickMomentum(dt: dt, size: lastSize)
            if extra.commands.isEmpty == false {
                emit(extra)
            }
        }
        if animation != latestAnimation {
            animation = latestAnimation
        }
    }
}

protocol CommandSending: AnyObject {
    func send(_ command: RemoteCommand)
}

private final class SenderBox {
    weak var sender: CommandSending?
}
