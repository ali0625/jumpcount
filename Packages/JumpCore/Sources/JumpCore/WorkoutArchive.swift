import Foundation

/// Callers serialize access; each record is saved atomically before it is synchronized.
public final class WorkoutArchive {
    public let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func local() throws -> WorkoutArchive {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return try WorkoutArchive(directory: documents.appendingPathComponent("Workouts", isDirectory: true))
    }

    public func logURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("csv")
    }

    public func save(_ record: WorkoutRecord) throws {
        guard record.isValid else { throw ArchiveError.invalidRecord }
        let data = try JSONEncoder().encode(record)
        try data.write(to: recordURL(for: record.id), options: .atomic)
    }

    public func records() throws -> [WorkoutRecord] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> WorkoutRecord? in
                guard let data = try? Data(contentsOf: url),
                      let record = try? JSONDecoder().decode(WorkoutRecord.self, from: data),
                      record.isValid else { return nil }
                return record
            }
            .sorted { $0.date > $1.date }
    }

    public func importLog(from temporaryURL: URL, for record: WorkoutRecord) throws {
        guard record.isValid else { throw ArchiveError.invalidRecord }
        // WCSession's temporary source disappears after the delegate returns.
        let data = try Data(contentsOf: temporaryURL)
        try data.write(to: logURL(for: record.id), options: .atomic)
        try save(record)
    }

    private func recordURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    public enum ArchiveError: Error { case invalidRecord }
}
