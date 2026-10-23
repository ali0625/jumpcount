import Foundation

/// Compile with JumpCounter.swift and RelativePeakDetector.swift, then pass CSV paths.
/// Replays original sensor magnitudes through the same implementation used on Watch.
@main
struct ReplayCounter {
    static func main() throws {
        guard CommandLine.arguments.count > 1 else {
            print("Usage: replay-counter log.csv [log2.csv ...]")
            return
        }
        for path in CommandLine.arguments.dropFirst() {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            var counter = JumpCounter()
            var samples = 0
            var oldCount = 0
            for line in contents.split(separator: "\n") where line.hasPrefix("sample,") {
                let columns = line.split(separator: ",", omittingEmptySubsequences: false)
                guard columns.count >= 10,
                      let timestamp = Double(columns[1]),
                      let magnitude = Double(columns[6]),
                      let recorded = Int(columns[9]) else {
                    throw NSError(domain: "Invalid CSV sample", code: 1)
                }
                counter.process(magnitude: magnitude, timestamp: timestamp)
                samples += 1
                oldCount = recorded
            }
            print("\(URL(fileURLWithPath: path).lastPathComponent): samples=\(samples), recorded=\(oldCount), replayed=\(counter.count)")
        }
    }
}
