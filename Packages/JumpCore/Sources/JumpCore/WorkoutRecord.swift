import Foundation

public struct WorkoutRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let count: Int
    public let duration: TimeInterval
    public let date: Date

    public init(id: UUID = UUID(), count: Int, duration: TimeInterval, date: Date) {
        self.id = id
        self.count = count
        self.duration = duration
        self.date = date
    }

    public var isValid: Bool {
        count >= 0 && duration.isFinite && duration >= 0 && date.timeIntervalSince1970.isFinite
    }

    public var cadence: Double {
        duration > 0 ? Double(count) * 60 / duration : 0
    }

    public static func inserting(_ record: WorkoutRecord, into records: [WorkoutRecord]) -> [WorkoutRecord] {
        guard record.isValid, !records.contains(where: { $0.id == record.id }) else { return records }
        return (records + [record]).sorted { $0.date > $1.date }
    }
}
