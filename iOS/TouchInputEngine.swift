import QuartzCore
import UIKit

final class TouchInputEngine: NSObject, ObservableObject {
    @Published private(set) var animation = TouchAnimationState.idle
    @Published private(set) var stats = TouchPipelineStats()

    var sensitivity: Double = 1.8

    private let udp: UDPClient
    private var latestAnimation = TouchAnimationState.idle
    private var displayLink: CADisplayLink?

    private var lastPoint: CGPoint?
    private var lastTimestamp: TimeInterval = 0
    private var startPoint: CGPoint?
    private var startTime: TimeInterval = 0
    private var peakMovement: CGFloat = 0
    private var activeFingerCount = 0
    private var isMouseDown = false
    private var longPressWorkItem: DispatchWorkItem?
    private var lastClickTime: TimeInterval = 0
    private var lastTwoFingerCentroid: CGPoint?
    private var lastUIKitTouch = Date.distantPast
    private var swiftUIPoint: CGPoint?
    private var movesThisSecond = 0
    private var secondTimer: Timer?

    init(udp: UDPClient) {
        self.udp = udp
        super.init()
        startDisplayLink()
        startSecondTimer()
    }

    deinit {
        displayLink?.invalidate()
        secondTimer?.invalidate()
    }

    func markUIKitTouch() {
        lastUIKitTouch = Date()
    }

    func syncConnection(_ isConnected: Bool) {
        var next = latestAnimation
        next.isConnected = isConnected
        latestAnimation = next
    }

    func handleBegan(points: [CGPoint], timestamp: TimeInterval, in size: CGSize) {
        Haptics.prepare()
        activeFingerCount = points.count
        startTime = timestamp
        peakMovement = 0
        lastTimestamp = timestamp
        stats.touchActive = true
        stats.touchCount += 1

        if points.count >= 2 {
            cancelLongPress()
            let center = centroid(points)
            lastPoint = center
            lastTwoFingerCentroid = center
            startPoint = center
        } else if let point = points.first {
            lastPoint = point
            startPoint = point
            lastTwoFingerCentroid = nil
            scheduleLongPress()
        }

        if let point = points.first {
            stats.x = point.x
            stats.y = point.y
        }

        publish(
            fingerCount: points.count,
            points: points,
            velocity: .zero,
            isFingerDown: true,
            isDragging: isMouseDown,
            size: size
        )
    }

    func handleMoved(points: [CGPoint], timestamp: TimeInterval, in size: CGSize) {
        let dt = max(timestamp - lastTimestamp, 0.001)
        activeFingerCount = max(activeFingerCount, points.count)

        if points.count >= 2 {
            cancelLongPress()
            let center = centroid(points)
            if let previous = lastTwoFingerCentroid ?? lastPoint {
                let dx = Double(center.x - previous.x)
                let dy = Double(center.y - previous.y)
                peakMovement = max(peakMovement, hypot(center.x - (startPoint?.x ?? center.x), center.y - (startPoint?.y ?? center.y)))
                let scaled = accelerate(dx: dx, dy: dy)
                udp.send(.scroll(dx: scaled.dx, dy: scaled.dy))
                stats.packetsSent += 1
                publish(
                    fingerCount: 2,
                    points: points,
                    velocity: CGSize(width: dx / dt, height: dy / dt),
                    isFingerDown: true,
                    isDragging: false,
                    size: size
                )
            }
            lastTwoFingerCentroid = center
            lastPoint = center
        } else if let point = points.first, let previous = lastPoint {
            let dx = Double(point.x - previous.x)
            let dy = Double(point.y - previous.y)
            peakMovement = max(peakMovement, hypot(point.x - (startPoint?.x ?? point.x), point.y - (startPoint?.y ?? point.y)))
            if peakMovement > 10 {
                cancelLongPress()
            }
            let scaled = accelerate(dx: dx, dy: dy)
            sendMove(dx: scaled.dx, dy: scaled.dy, at: point)
            publish(
                fingerCount: 1,
                points: points,
                velocity: CGSize(width: dx / dt, height: dy / dt),
                isFingerDown: true,
                isDragging: isMouseDown,
                size: size
            )
            lastPoint = point
        }

        lastTimestamp = timestamp
    }

    func handleEnded(remainingCount: Int, timestamp: TimeInterval, in size: CGSize) {
        cancelLongPress()

        if remainingCount == 0 {
            let duration = timestamp - startTime
            let wasTwoFinger = activeFingerCount >= 2
            let isTap = peakMovement < 12 && duration < 0.32

            if isMouseDown {
                udp.send(.mouseUp)
                isMouseDown = false
                stats.packetsSent += 1
            } else if isTap {
                if wasTwoFinger {
                    udp.send(.rightClick)
                    Haptics.rightClick()
                    bumpClick(double: false, size: size)
                } else {
                    udp.send(.click)
                    Haptics.click()
                    let isDouble = timestamp - lastClickTime < 0.3
                    lastClickTime = timestamp
                    bumpClick(double: isDouble, size: size)
                }
                stats.packetsSent += 1
            }

            activeFingerCount = 0
            lastPoint = nil
            lastTwoFingerCentroid = nil
            startPoint = nil
            stats.touchActive = false
            stats.dx = 0
            stats.dy = 0
            publish(
                fingerCount: 0,
                points: [],
                velocity: .zero,
                isFingerDown: false,
                isDragging: false,
                size: size
            )
        }
    }

    func handleCancelled(in size: CGSize) {
        cancelLongPress()
        if isMouseDown {
            udp.send(.mouseUp)
            isMouseDown = false
        }
        activeFingerCount = 0
        lastPoint = nil
        lastTwoFingerCentroid = nil
        stats.touchActive = false
        publish(
            fingerCount: 0,
            points: [],
            velocity: .zero,
            isFingerDown: false,
            isDragging: false,
            size: size
        )
    }

    func handleSwiftUIDrag(location: CGPoint, in size: CGSize) {
        if Date().timeIntervalSince(lastUIKitTouch) < 0.08 { return }
        stats.touchCount += 1
        stats.touchActive = true
        stats.x = location.x
        stats.y = location.y
        if let previous = swiftUIPoint {
            let dx = Double(location.x - previous.x)
            let dy = Double(location.y - previous.y)
            let scaled = accelerate(dx: dx, dy: dy)
            sendMove(dx: scaled.dx, dy: scaled.dy, at: location)
            publish(
                fingerCount: 1,
                points: [location],
                velocity: CGSize(width: dx * 60, height: dy * 60),
                isFingerDown: true,
                isDragging: isMouseDown,
                size: size
            )
        } else {
            publish(
                fingerCount: 1,
                points: [location],
                velocity: .zero,
                isFingerDown: true,
                isDragging: isMouseDown,
                size: size
            )
        }
        swiftUIPoint = location
    }

    func handleSwiftUIDragEnded(in size: CGSize) {
        if Date().timeIntervalSince(lastUIKitTouch) < 0.08 { return }
        swiftUIPoint = nil
        stats.touchActive = false
        stats.dx = 0
        stats.dy = 0
        publish(
            fingerCount: 0,
            points: [],
            velocity: .zero,
            isFingerDown: false,
            isDragging: false,
            size: size
        )
    }

    private func sendMove(dx: Double, dy: Double, at point: CGPoint) {
        udp.send(.move(dx: dx, dy: dy))
        movesThisSecond += 1
        stats.x = point.x
        stats.y = point.y
        stats.dx = dx
        stats.dy = dy
        stats.packetsSent += 1
        stats.moveSent += 1
    }

    private func scheduleLongPress() {
        cancelLongPress()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.peakMovement < 10, !self.isMouseDown else { return }
            self.isMouseDown = true
            self.udp.send(.mouseDown)
            self.stats.packetsSent += 1
            Haptics.mouseDown()
            var next = self.latestAnimation
            next.isDragging = true
            self.latestAnimation = next
        }
        longPressWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: work)
    }

    private func cancelLongPress() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
    }

    private func accelerate(dx: Double, dy: Double) -> (dx: Double, dy: Double) {
        let magnitude = hypot(dx, dy)
        let boost = 1.0 + min(magnitude / 10.0, 2.2)
        return (dx * sensitivity * boost, dy * sensitivity * boost)
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let count = CGFloat(max(points.count, 1))
        return CGPoint(x: total.x / count, y: total.y / count)
    }

    private func bumpClick(double: Bool, size: CGSize) {
        var next = latestAnimation
        next.clickPulse += 1
        if double { next.doubleClickPulse += 1 }
        next.trackpadSize = size
        latestAnimation = next
    }

    private func publish(
        fingerCount: Int,
        points: [CGPoint],
        velocity: CGSize,
        isFingerDown: Bool,
        isDragging: Bool,
        size: CGSize
    ) {
        latestAnimation = TouchAnimationState(
            isConnected: udp.isConnected,
            fingerCount: fingerCount,
            points: points,
            velocity: velocity,
            isFingerDown: isFingerDown,
            isDragging: isDragging,
            clickPulse: latestAnimation.clickPulse,
            doubleClickPulse: latestAnimation.doubleClickPulse,
            trackpadSize: size
        )
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
