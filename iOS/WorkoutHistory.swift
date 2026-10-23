import Foundation
import WatchConnectivity
import Combine
import JumpCore

@MainActor
final class WorkoutHistory: ObservableObject {
    @Published private(set) var records: [WorkoutRecord] = []

    private let storageKey = "workoutRecords"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
            records = saved
        }
        PhoneSessionBridge.shared.onWorkout = { [weak self] record in
            self?.add(record)
        }
        PhoneSessionBridge.shared.activate()
    }

    private func add(_ record: WorkoutRecord) {
        records = WorkoutRecord.inserting(record, into: records)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

private final class PhoneSessionBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionBridge()
    var onWorkout: ((WorkoutRecord) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let idString = userInfo["id"] as? String,
              let id = UUID(uuidString: idString),
              let count = userInfo["count"] as? Int,
              let duration = userInfo["duration"] as? Double,
              let timestamp = userInfo["date"] as? Double else { return }
        let record = WorkoutRecord(id: id, count: count, duration: duration, date: Date(timeIntervalSince1970: timestamp))
        DispatchQueue.main.async { self.onWorkout?(record) }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
