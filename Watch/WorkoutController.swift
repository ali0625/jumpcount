import Foundation
import WatchConnectivity
import Combine
import JumpCore

@MainActor
final class WorkoutController: ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var startedAt: Date?
    @Published private(set) var elapsed: TimeInterval = 0

    private let detector = JumpDetector()
    private var timer: Timer?

    var isRunning: Bool { startedAt != nil }

    init() {
        detector.onJump = { [weak self] in self?.count += 1 }
        WatchSessionBridge.shared.activate()
    }

    func start() {
        guard !isRunning else { return }
        count = 0
        elapsed = 0
        startedAt = Date()
        detector.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
    }

    func stop() {
        guard let startedAt else { return }
        detector.stop()
        timer?.invalidate()
        timer = nil
        elapsed = Date().timeIntervalSince(startedAt)
        self.startedAt = nil
        WatchSessionBridge.shared.sendWorkout(WorkoutRecord(count: count, duration: elapsed, date: startedAt))
    }
}

private final class WatchSessionBridge: NSObject, WCSessionDelegate {
    static let shared = WatchSessionBridge()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendWorkout(_ record: WorkoutRecord) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo([
            "id": record.id.uuidString,
            "count": record.count,
            "duration": record.duration,
            "date": record.date.timeIntervalSince1970
        ])
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionReachabilityDidChange(_ session: WCSession) {}
}
