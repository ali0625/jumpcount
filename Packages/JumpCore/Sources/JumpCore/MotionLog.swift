import Foundation

public struct MotionLogSample {
    public let timestamp: TimeInterval
    public let x: Double
    public let y: Double
    public let z: Double
    public let magnitude: Double
    public let filtered: Double
    public let isJump: Bool
    public let count: Int

    public init(timestamp: TimeInterval, x: Double, y: Double, z: Double,
                magnitude: Double, filtered: Double, isJump: Bool, count: Int) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
        self.magnitude = magnitude
        self.filtered = filtered
        self.isJump = isJump
        self.count = count
    }
}

/// Buffered streaming CSV: memory usage stays bounded during a long workout.
public final class MotionLogWriter {
    public static let header = "event,sensor_seconds,elapsed_seconds,x_g,y_g,z_g,magnitude_g,filtered_g,is_jump,count,detail\n"
    private var handle: FileHandle?
    private var buffer = ""
    private var bufferedRows = 0
    private var firstTimestamp: TimeInterval?

    public init(url: URL, sessionID: UUID, startedAt: Date) throws {
        // The UUID file name belongs to this session; never append to another training log.
        try Data(Self.header.utf8).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        self.handle = handle
        let date = ISO8601DateFormatter().string(from: startedAt)
        try event("start", count: 0, detail: "session=\(sessionID.uuidString);date=\(date);algorithm=peakdetect-v1;delta_g=0.15;minimum_interval_s=0.23;warmup_samples=15;lookahead_samples=3;filtered_column=magnitude_minus_1g")
        try flush()
    }

    public func append(_ sample: MotionLogSample) throws {
        if firstTimestamp == nil { firstTimestamp = sample.timestamp }
        let elapsed = sample.timestamp - (firstTimestamp ?? sample.timestamp)
        let values = ["sample", number(sample.timestamp), number(elapsed),
                      number(sample.x), number(sample.y), number(sample.z),
                      number(sample.magnitude), number(sample.filtered),
                      sample.isJump ? "1" : "0", String(sample.count), ""]
        try appendRow(values.joined(separator: ",") + "\n")
    }

    public func event(_ name: String, count: Int, detail: String) throws {
        let safe = detail.replacingOccurrences(of: "\"", with: "\"\"")
        try appendRow("\(name),,,,,,,,,\(count),\"\(safe)\"\n")
    }

    public func finish(count: Int, reason: String) throws {
        try event("stop", count: count, detail: reason)
        try flush()
        try handle?.close()
        handle = nil
    }

    private func appendRow(_ row: String) throws {
        guard handle != nil else { throw LogError.closed }
        buffer += row
        bufferedRows += 1
        if bufferedRows >= 25 { try flush() }
    }

    private func flush() throws {
        guard let handle, !buffer.isEmpty else { return }
        try handle.write(contentsOf: Data(buffer.utf8))
        buffer = ""
        bufferedRows = 0
    }

    private func number(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    deinit { try? handle?.close() }
    public enum LogError: Error { case closed }
}
