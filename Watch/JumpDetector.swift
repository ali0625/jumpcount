import CoreMotion
import Foundation
import JumpCore

@MainActor
final class JumpDetector {
    var onSample: ((Int) -> Void)?
    var onError: ((String) -> Void)?
    private let motionManager = CMMotionManager()
    private var counter = JumpCounter()
    private var writer: MotionLogWriter?
    private var runID: UUID?

    func start(logURL: URL, sessionID: UUID, startedAt: Date) throws {
        guard motionManager.isAccelerometerAvailable else { throw SensorError.unavailable }
        counter.reset()
        writer = try MotionLogWriter(url: logURL, sessionID: sessionID, startedAt: startedAt)
        runID = sessionID
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] sample, error in
            Task { @MainActor in
                guard let self, self.runID == sessionID else { return }
                if let error {
                    let detail = error.localizedDescription
                    try? self.writer?.event("sensor_error", count: self.counter.count, detail: detail)
                    self.onError?("运动数据读取失败：\(detail)")
                    return
                }
                guard let sample else { return }
                let a = sample.acceleration
                let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
                let jumped = self.counter.process(magnitude: magnitude, timestamp: sample.timestamp)
                do {
                    try self.writer?.append(MotionLogSample(
                        timestamp: sample.timestamp, x: a.x, y: a.y, z: a.z,
                        magnitude: magnitude, filtered: self.counter.filteredSignal,
                        isJump: jumped, count: self.counter.count
                    ))
                } catch {
                    self.onError?("日志写入失败：\(error.localizedDescription)")
                    self.writer = nil
                }
                self.onSample?(self.counter.count)
            }
        }
    }

    func stop(reason: String) throws {
        runID = nil
        motionManager.stopAccelerometerUpdates()
        try writer?.finish(count: counter.count, reason: reason)
        writer = nil
    }

    enum SensorError: LocalizedError {
        case unavailable
        var errorDescription: String? { "没有可用的加速度计，请使用真实 Apple Watch。" }
    }
}
