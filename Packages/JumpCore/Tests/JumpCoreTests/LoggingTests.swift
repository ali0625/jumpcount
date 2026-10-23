import XCTest
@testable import JumpCore

final class LoggingTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    func testArchiveSurvivesReloadAndRepeatedDeliveryDoesNotDuplicate() throws {
        let directory = try temporaryDirectory()
        let archive = try WorkoutArchive(directory: directory)
        let record = WorkoutRecord(count: 100, duration: 60, date: Date())
        try archive.save(record)
        try archive.save(record)
        let reloaded = try WorkoutArchive(directory: directory)
        XCTAssertEqual(try reloaded.records(), [record])
        XCTAssertThrowsError(try archive.save(WorkoutRecord(count: -1, duration: 60, date: Date())))
    }

    func testMotionLogContainsEverySampleAndFinalPartialBuffer() throws {
        let directory = try temporaryDirectory()
        let archive = try WorkoutArchive(directory: directory)
        let record = WorkoutRecord(count: 1, duration: 1, date: Date())
        let url = archive.logURL(for: record.id)
        let writer = try MotionLogWriter(url: url, sessionID: record.id, startedAt: record.date)
        for index in 0..<53 {
            try writer.append(MotionLogSample(timestamp: 100 + Double(index) / 50, x: 0, y: 0, z: 1,
                                              magnitude: 1, filtered: 0, isJump: index == 50,
                                              count: index >= 50 ? 1 : 0))
        }
        try writer.finish(count: 1, reason: "manual")
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 56) // header, start, 53 samples, stop
        XCTAssertTrue(text.contains("sample,100.000000,0.000000,"))
        XCTAssertTrue(text.contains("stop,,,,,,,,,1,\"manual\""))
        XCTAssertThrowsError(try writer.event("test", count: 1, detail: "already closed"))
    }

    func testIncomingTemporaryLogIsCopiedBeforeSourceDisappears() throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("received.csv")
        try Data(MotionLogWriter.header.utf8).write(to: source)
        let archive = try WorkoutArchive(directory: directory.appendingPathComponent("archive"))
        let record = WorkoutRecord(count: 4, duration: 2, date: Date())
        try archive.importLog(from: source, for: record)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try String(contentsOf: archive.logURL(for: record.id), encoding: .utf8), MotionLogWriter.header)
        XCTAssertEqual(try archive.records(), [record])
    }
}
