import Foundation

/// Relative peak detection adapted from peakdetect; still requires wrist calibration.
/// Input: acceleration magnitude in g and the sensor's monotonic timestamp in seconds.
public struct JumpCounter {
    public struct Configuration {
        public var threshold: Double
        public var minimumInterval: TimeInterval

        public init(threshold: Double = 0.15, minimumInterval: TimeInterval = 0.23) {
            self.threshold = threshold.isFinite ? max(0.05, threshold) : 0.15
            self.minimumInterval = minimumInterval.isFinite ? max(0.15, minimumInterval) : 0.23
        }
    }

    public private(set) var count = 0
    public private(set) var filteredSignal = 0.0
    private let configuration: Configuration
    private var peaks: RelativePeakDetector
    private var previousTimestamp: TimeInterval?
    private var lastJumpTimestamp: TimeInterval?
    private var warmupSamples = 0

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.peaks = RelativePeakDetector(delta: configuration.threshold)
    }

    public mutating func reset() {
        self = JumpCounter(configuration: configuration)
    }

    /// After pausing or a data gap, retain the count but warm up the filters again.
    public mutating func resume() {
        filteredSignal = 0
        peaks = RelativePeakDetector(delta: configuration.threshold)
        previousTimestamp = nil
        lastJumpTimestamp = nil
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
        // Kept as a zero-centered diagnostic column. Peak detection uses raw
        // magnitude: the old low-pass/high-pass chain removed small wrist peaks.
        filteredSignal = magnitude - 1
        warmupSamples += 1
        guard warmupSamples > 15 else { return false }

        guard let peakTimestamp = peaks.process(value: magnitude, timestamp: timestamp) else { return false }
        if let lastJumpTimestamp,
           peakTimestamp - lastJumpTimestamp < configuration.minimumInterval { return false }
        lastJumpTimestamp = peakTimestamp
        count += 1
        return true
    }
}
