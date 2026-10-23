import CoreMotion
import Foundation
import JumpCore

final class JumpDetector {
    var onJump: (() -> Void)?

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var counter = JumpCounter()

    init() {
        queue.name = "com.personal.ropeskip.motion"
        queue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        counter.reset()
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] sample, _ in
            guard let self, let sample else { return }
            let acceleration = sample.acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            if self.counter.process(magnitude: magnitude, timestamp: sample.timestamp) {
                DispatchQueue.main.async { self.onJump?() }
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
