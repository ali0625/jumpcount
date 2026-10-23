import Combine
import Foundation
import JumpCore

@MainActor
final class WorkoutController: ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var startedAt: Date?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    let sync = WorkoutSync()
    private let detector = JumpDetector()
    private var timer: Timer?
    private var sessionID: UUID?
    private var startedUptime: TimeInterval?
    private var unsavedRecord: WorkoutRecord?

    var isRunning: Bool { startedAt != nil }
    var hasUnsavedRecord: Bool { unsavedRecord != nil }

    init() {
        detector.onSample = { [weak self] count in
            guard let self, self.isRunning else { return }
            self.count = count
        }
        detector.onError = { [weak self] message in self?.errorMessage = message }
    }

    func start() {
        guard !isRunning, unsavedRecord == nil else { return }
        let id = UUID()
        let date = Date()
        do {
            let url = try sync.logURL(for: id)
            try detector.start(logURL: url, sessionID: id, startedAt: date)
            count = 0
            elapsed = 0
            errorMessage = nil
            sessionID = id
            startedAt = date
            startedUptime = ProcessInfo.processInfo.systemUptime
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshElapsed() }
            }
        } catch { errorMessage = "无法开始：\(error.localizedDescription)" }
    }

    func stop(reason: String = "manual") {
        guard let date = startedAt, let id = sessionID else { return }
        refreshElapsed()
        startedAt = nil
        startedUptime = nil
        sessionID = nil
        timer?.invalidate()
        timer = nil
        do { try detector.stop(reason: reason) }
        catch { errorMessage = "日志未完整保存：\(error.localizedDescription)" }
        unsavedRecord = WorkoutRecord(id: id, count: count, duration: elapsed, date: date)
        retrySave()
    }

    func retrySave() {
        guard let record = unsavedRecord else { return }
        do {
            try sync.save(record)
            unsavedRecord = nil
        } catch { errorMessage = "保存失败，请点击重试保存：\(error.localizedDescription)" }
    }

    private func refreshElapsed() {
        guard let startedUptime else { return }
        elapsed = ProcessInfo.processInfo.systemUptime - startedUptime
    }
}
