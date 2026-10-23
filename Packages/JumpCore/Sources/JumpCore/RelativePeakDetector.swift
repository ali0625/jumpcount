import Foundation

/// Streaming Swift adaptation of peakdetect() by Harley King / Sixten Bergman,
/// based on Eli Billauer's peakdet. Upstream commit and MIT notice:
/// ThirdParty/peakdetect-LICENSE.txt and ALGORITHM.md.
///
/// Confirms extrema using their relative drop/rise and a short lookahead.
/// Unlike an absolute threshold, the peak may sit above a changing baseline.
struct RelativePeakDetector {
    struct Sample {
        let value: Double
        let timestamp: TimeInterval
    }

    let delta: Double
    let lookahead: Int
    private var pending: [Sample] = []
    private var minimum = Double.infinity
    private var maximum = -Double.infinity
    private var maximumTimestamp: TimeInterval = 0
    private var foundFirstExtremum = false

    init(delta: Double, lookahead: Int = 3) {
        self.delta = delta
        self.lookahead = max(1, lookahead)
    }

    mutating func process(value: Double, timestamp: TimeInterval) -> TimeInterval? {
        pending.append(Sample(value: value, timestamp: timestamp))
        // Match upstream's exclusion of the final `lookahead` samples.
        guard pending.count > lookahead else { return nil }
        let sample = pending[0]
        let future = pending.prefix(lookahead)
        defer { pending.removeFirst() }

        if sample.value > maximum {
            maximum = sample.value
            maximumTimestamp = sample.timestamp
        }
        if sample.value < minimum { minimum = sample.value }

        if sample.value < maximum - delta, maximum != .infinity,
           future.allSatisfy({ $0.value < maximum }) {
            let peakTimestamp = maximumTimestamp
            maximum = .infinity
            minimum = .infinity
            // Upstream removes the first extremum, which may be a boundary artifact.
            let shouldEmit = foundFirstExtremum
            foundFirstExtremum = true
            return shouldEmit ? peakTimestamp : nil
        }

        if sample.value > minimum + delta, minimum != -.infinity,
           future.allSatisfy({ $0.value > minimum }) {
            minimum = -.infinity
            maximum = -.infinity
            foundFirstExtremum = true
        }
        return nil
    }
}
