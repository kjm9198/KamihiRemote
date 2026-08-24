import QuartzCore
import UIKit

final class TouchInputEngine: NSObject, ObservableObject {
    @Published private(set) var animation = TouchAnimationState.idle
    @Published private(set) var stats = TouchPipelineStats()
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
        if phase == .began {
            stats.touchActive = true
            stats.touchCount += 1
            stats.touchActive = true
        }
        let output = gesture.handle(samples: samples, timestamp: timestamp, phase: phase, in: size)
        emit(output)
        if phase == .ended || phase == .cancelled {
            if samples.isEmpty || gesture.mode == .idle {
                stats.touchActive = false
                stats.dx = 0
                stats.dy = 0
            }
        }
        if let point = samples.first?.point {
            stats.x = point.x
            stats.y = point.y
        }
    }

    func handleCancelled(in size: CGSize) {
        emit(gesture.cancel(size: size))
        stats.touchActive = false
        stats.dx = 0
        stats.dy = 0
    }

    func orientationChanged(in size: CGSize) {
        handleCancelled(in: size)
    }

    private func emit(_ output: GestureOutput) {
        latestAnimation = output.animation
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
