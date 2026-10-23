import Foundation

/// A starting point for detecting wrist acceleration peaks. Calibrate on a real watch.
/// Input: acceleration magnitude in g and the sensor's monotonic timestamp in seconds.
public struct JumpCounter {
    public struct Configuration {
        public var threshold: Double
        public var minimumInterval: TimeInterval

        public init(threshold: Double = 0.25, minimumInterval: TimeInterval = 0.23) {
            self.threshold = threshold.isFinite ? max(0.05, threshold) : 0.25
            self.minimumInterval = minimumInterval.isFinite ? max(0.15, minimumInterval) : 0.23
        }
    }

    public private(set) var count = 0
    public private(set) var filteredSignal = 0.0
    private let configuration: Configuration
    private var baseline = 1.0
    private var previousTimestamp: TimeInterval?
    private var lastJumpTimestamp: TimeInterval?
    private var armed = false
    private var warmupSamples = 0

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public mutating func reset() {
        self = JumpCounter(configuration: configuration)
    }

    /// After pausing or a data gap, retain the count but warm up the filters again.
    public mutating func resume() {
        baseline = 1
        filteredSignal = 0
        previousTimestamp = nil
        lastJumpTimestamp = nil
        armed = false
        warmupSamples = 0
    }

    @discardableResult
    public mutating func process(magnitude: Double, timestamp: TimeInterval) -> Bool {
        guard magnitude.isFinite, (0...16).contains(magnitude),
              timestamp.isFinite, timestamp >= 0 else { return false }
        if let previousTimestamp {
            guard timestamp > previousTimestamp else { return false }
            if timestamp - previousTimestamp > 0.5 { resume() }
        }
        previousTimestamp = timestamp
        baseline += 0.04 * (magnitude - baseline)
        filteredSignal += 0.4 * ((magnitude - baseline) - filteredSignal)
        warmupSamples += 1
        guard warmupSamples > 15 else { return false }

        // Hysteresis requires a distinct valley before another rising peak.
        if filteredSignal < configuration.threshold * 0.4 { armed = true }
        guard armed, filteredSignal >= configuration.threshold else { return false }
        armed = false
        if let lastJumpTimestamp,
           timestamp - lastJumpTimestamp < configuration.minimumInterval { return false }
        lastJumpTimestamp = timestamp
        count += 1
        return true
    }
}
