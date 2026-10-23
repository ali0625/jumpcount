import Combine
import Foundation
import JumpCore
import WatchConnectivity

@MainActor
final class WorkoutSync: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var records: [WorkoutRecord] = []
    @Published private(set) var message = "正在连接"
    @Published private(set) var errorMessage: String?
    @Published private(set) var logIDs: Set<UUID> = []
    private var archive: WorkoutArchive?
    private let recordReceiptsKey = "syncedWorkoutRecords"
    private let logReceiptsKey = "syncedWorkoutLogs"

    override init() {
        super.init()
        do {
            archive = try WorkoutArchive.local()
            if let data = UserDefaults.standard.data(forKey: "workoutRecords"),
               let old = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
                for record in old where record.isValid { try archive?.save(record) }
                UserDefaults.standard.removeObject(forKey: "workoutRecords")
            }
            try reload()
        } catch { errorMessage = "无法读取本地记录：\(error.localizedDescription)" }
        #if ROPE_STANDALONE
        message = "训练和运动日志保存在手表本地"
        #else
        guard WCSession.isSupported() else {
            message = "此设备不支持手表同步"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #endif
    }

    func logURL(for id: UUID) throws -> URL {
        guard let archive else { throw SyncError.storageUnavailable }
        return archive.logURL(for: id)
    }

    func save(_ record: WorkoutRecord) throws {
        guard let archive else { throw SyncError.storageUnavailable }
        try archive.save(record)
        try reload()
        synchronize()
    }

    func synchronize(retryAll: Bool = false) {
        #if ROPE_STANDALONE
        message = "训练和运动日志保存在手表本地"
        return
        #else
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            message = "已保存在本机，等待连接"
            return
        }
        #if os(watchOS)
        guard session.isCompanionAppInstalled else {
            message = "已保存，请先安装手机 App"
            return
        }
        if retryAll {
            UserDefaults.standard.removeObject(forKey: recordReceiptsKey)
            UserDefaults.standard.removeObject(forKey: logReceiptsKey)
        }
        let recordReceipts = receipts(recordReceiptsKey)
        let logReceipts = receipts(logReceiptsKey)
        let queuedRecords = Set(session.outstandingUserInfoTransfers.compactMap { $0.userInfo["id"] as? String })
        let queuedLogs = Set(session.outstandingFileTransfers.compactMap { $0.file.metadata?["id"] as? String })
        do {
            for record in records {
                let id = record.id.uuidString
                let metadata: [String: Any] = ["version": 1, "id": id, "record": try JSONEncoder().encode(record)]
                if !recordReceipts.contains(id), !queuedRecords.contains(id) {
                    session.transferUserInfo(metadata)
                }
                if logIDs.contains(record.id), !logReceipts.contains(id), !queuedLogs.contains(id) {
                    session.transferFile(try logURL(for: record.id), metadata: metadata)
                }
            }
            message = "记录已保存；同步由系统安排"
        } catch { errorMessage = "同步排队失败：\(error.localizedDescription)" }
        #else
        message = session.isPaired && session.isWatchAppInstalled ? "等待手表记录和日志" : "请连接并安装手表 App"
        #endif
        #endif
    }

    private func reload() throws {
        records = try archive?.records() ?? []
        logIDs = Set(records.filter {
            guard let url = archive?.logURL(for: $0.id) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }.map(\.id))
    }

    private func receipts(_ key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func complete(id: String?, key: String, error: Error?) {
        if let error {
            errorMessage = "同步未完成，可稍后重试：\(error.localizedDescription)"
            return
        }
        guard let id else { return }
        var ids = receipts(key)
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: key)
        message = "已传送到手机"
    }

    nonisolated private static func record(from metadata: [String: Any]?) -> WorkoutRecord? {
        guard let data = metadata?["record"] as? Data,
              let record = try? JSONDecoder().decode(WorkoutRecord.self, from: data),
              record.isValid else { return nil }
        return record
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error { self.errorMessage = "连接失败：\(error.localizedDescription)" }
            else { self.synchronize() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let record = Self.record(from: userInfo) else { return }
        do {
            try WorkoutArchive.local().save(record)
            Task { @MainActor in
                try? self.reload()
                self.message = "已收到训练记录"
            }
        } catch {
            let detail = error.localizedDescription
            Task { @MainActor in self.errorMessage = "保存记录失败：\(detail)" }
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let record = Self.record(from: file.metadata) else { return }
        do {
            // The WCSession temporary file expires after this delegate returns.
            try WorkoutArchive.local().importLog(from: file.fileURL, for: record)
            Task { @MainActor in
                try? self.reload()
                self.message = "日志已收到，可以导出"
            }
        } catch {
            let detail = error.localizedDescription
            Task { @MainActor in self.errorMessage = "接收日志失败，请在手表重试同步：\(detail)" }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let id = userInfoTransfer.userInfo["id"] as? String
        Task { @MainActor in self.complete(id: id, key: self.recordReceiptsKey, error: error) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let id = fileTransfer.file.metadata?["id"] as? String
        Task { @MainActor in self.complete(id: id, key: self.logReceiptsKey, error: error) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    enum SyncError: Error { case storageUnavailable }
}
