import Foundation

public enum MotionIntensity: Int, CaseIterable, Codable, Comparable, Sendable {
    case still, light, moderate, vigorous

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var name: String {
        switch self {
        case .still: return "Still"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .vigorous: return "Vigorous"
        }
    }

    /// Wrist-worn ENMO cut-points in milli-g (Hildebrand et al., 2014).
    public init(enmoMilliG: Double) {
        switch enmoMilliG {
        case ..<45: self = .still
        case ..<100: self = .light
        case ..<400: self = .moderate
        default: self = .vigorous
        }
    }
}

public struct MotionSnapshot: Codable, Hashable, Sendable {
    public let endDate: Date
    /// Euclidean norm minus one g, averaged over the window (milli-g).
    public let enmoMilliG: Double
    public let intensity: MotionIntensity
    /// Estimated rhythmic movements per minute (≈ steps/min when walking or running).
    public let cadence: Double
}

/// Turns raw Apple Watch accelerometer samples (in g) into movement intensity in real time.
///
/// Feed every sample with `add(x:y:z:timestamp:)`; a `MotionSnapshot` is returned each
/// time a window completes. Time spent in each intensity is accumulated for the session.
public struct MotionIntensityAnalyzer: Sendable {
    public let windowDuration: TimeInterval
    /// Acceleration magnitude (g) that counts as a stride/arm-swing peak.
    public var peakThreshold = 1.15
    /// Ignore peaks closer together than this (max ~4 steps/s).
    public var minimumPeakSpacing: TimeInterval = 0.25

    public private(set) var secondsByIntensity: [MotionIntensity: TimeInterval] = [:]
    public private(set) var latest: MotionSnapshot?

    private var windowStart: TimeInterval?
    private var enmoSum = 0.0
    private var sampleCount = 0
    private var peaks = 0
    private var lastPeakTime: TimeInterval = -.infinity
    private var previousMagnitude = 0.0
    private var risingEdge = false

    public init(windowDuration: TimeInterval = 5) {
        self.windowDuration = windowDuration
    }

    /// - Parameter timestamp: Seconds on a monotonic clock (e.g. `CMAccelerometerData.timestamp`).
    public mutating func add(x: Double, y: Double, z: Double, timestamp: TimeInterval) -> MotionSnapshot? {
        if windowStart == nil { windowStart = timestamp }
        let magnitude = (x * x + y * y + z * z).squareRoot()

        enmoSum += max(magnitude - 1, 0)
        sampleCount += 1

        // Count a peak when the signal turns downward above the threshold.
        if magnitude > previousMagnitude {
            risingEdge = true
        } else if risingEdge, previousMagnitude >= peakThreshold, timestamp - lastPeakTime >= minimumPeakSpacing {
            peaks += 1
            lastPeakTime = timestamp
            risingEdge = false
        } else {
            risingEdge = false
        }
        previousMagnitude = magnitude

        guard let start = windowStart, timestamp - start >= windowDuration else { return nil }
        let elapsed = timestamp - start
        let enmo = enmoSum / Double(sampleCount) * 1000
        let intensity = MotionIntensity(enmoMilliG: enmo)
        let snapshot = MotionSnapshot(
            endDate: Date(),
            enmoMilliG: enmo,
            intensity: intensity,
            cadence: Double(peaks) / elapsed * 60
        )
        secondsByIntensity[intensity, default: 0] += elapsed
        latest = snapshot

        windowStart = timestamp
        enmoSum = 0
        sampleCount = 0
        peaks = 0
        return snapshot
    }

    public mutating func reset() {
        var fresh = MotionIntensityAnalyzer(windowDuration: windowDuration)
        fresh.peakThreshold = peakThreshold
        fresh.minimumPeakSpacing = minimumPeakSpacing
        self = fresh
    }
}
