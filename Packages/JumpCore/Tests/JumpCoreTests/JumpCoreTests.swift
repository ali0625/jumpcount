import XCTest
@testable import JumpCore

final class JumpCoreTests: XCTestCase {
    func testRestAndSmallNoiseDoNotCount() {
        var counter = JumpCounter()
        for index in 0..<1500 {
            counter.process(magnitude: 1 + 0.035 * sin(Double(index)), timestamp: Double(index) / 50)
        }
        XCTAssertEqual(counter.count, 0)
    }

    func testRepeatedSeparatedPeaksCountOncePerCycle() {
        var counter = JumpCounter()
        var index = 0
        func sample(_ magnitude: Double) {
            counter.process(magnitude: magnitude, timestamp: Double(index) / 50)
            index += 1
        }
        for _ in 0..<50 { sample(1) }
        for _ in 0..<20 {
            for _ in 0..<5 { sample(2) }
            for _ in 0..<20 { sample(1) }
        }
        XCTAssertEqual(counter.count, 20)
    }

    func testRefractoryPeriodRejectsAnImmediateSecondPeak() {
        var counter = JumpCounter()
        for index in 0..<50 { counter.process(magnitude: 1, timestamp: Double(index) / 50) }
        for index in 50..<55 { counter.process(magnitude: 2, timestamp: Double(index) / 50) }
        for index in 55..<60 { counter.process(magnitude: 1, timestamp: Double(index) / 50) }
        for index in 60..<64 { counter.process(magnitude: 2, timestamp: Double(index) / 50) }
        XCTAssertEqual(counter.count, 1)
    }

    func testInvalidAndOutOfOrderSamplesDoNotChangeCount() {
        var counter = JumpCounter()
        for index in 0..<50 { counter.process(magnitude: 1, timestamp: Double(index) / 50) }
        XCTAssertFalse(counter.process(magnitude: .nan, timestamp: 2))
        XCTAssertFalse(counter.process(magnitude: .infinity, timestamp: 2))
        XCTAssertFalse(counter.process(magnitude: 30, timestamp: 2))
        XCTAssertFalse(counter.process(magnitude: 2, timestamp: 0.1))
        XCTAssertFalse(counter.process(magnitude: 2, timestamp: .nan))
        XCTAssertEqual(counter.count, 0)
    }

    func testResumeKeepsCountAndResetClearsIt() {
        var counter = JumpCounter()
        for index in 0..<50 { counter.process(magnitude: 1, timestamp: Double(index) / 50) }
        for index in 50..<55 { counter.process(magnitude: 2, timestamp: Double(index) / 50) }
        XCTAssertEqual(counter.count, 1)
        counter.resume()
        XCTAssertEqual(counter.count, 1)
        counter.reset()
        XCTAssertEqual(counter.count, 0)
    }

    func testDataGapWarmsUpAgainInsteadOfCountingInitialSpike() {
        var counter = JumpCounter()
        for index in 0..<50 { counter.process(magnitude: 1, timestamp: Double(index) / 50) }
        XCTAssertFalse(counter.process(magnitude: 3, timestamp: 10))
        XCTAssertEqual(counter.count, 0)
    }

    func testRecordRoundTripPreservesIdentityAndValues() throws {
        let record = WorkoutRecord(count: 120, duration: 60, date: Date())
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutRecord.self, from: data), record)
        XCTAssertEqual(record.cadence, 120)
    }

    func testSynchronizationDeduplicatesAndSortsByTrainingDate() {
        let older = WorkoutRecord(count: 2, duration: 3, date: Date(timeIntervalSince1970: 100))
        let newer = WorkoutRecord(count: 4, duration: 5, date: Date(timeIntervalSince1970: 200))
        let records = WorkoutRecord.inserting(older, into: [newer])
        XCTAssertEqual(records.map(\.id), [newer.id, older.id])
        XCTAssertEqual(WorkoutRecord.inserting(older, into: records).count, 2)
    }

    func testInvalidRecordsAreRejectedAndZeroDurationIsSafe() {
        let invalid = WorkoutRecord(count: -1, duration: 10, date: Date())
        XCTAssertTrue(WorkoutRecord.inserting(invalid, into: []).isEmpty)
        let zero = WorkoutRecord(count: 0, duration: 0, date: Date())
        XCTAssertEqual(zero.cadence, 0)
        XCTAssertFalse(WorkoutRecord(count: 1, duration: .infinity, date: Date()).isValid)
    }
}
