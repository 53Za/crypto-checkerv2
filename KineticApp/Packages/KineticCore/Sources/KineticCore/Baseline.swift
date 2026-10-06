import Foundation

/// Mean and standard deviation of a metric over the personal baseline window.
public struct MetricBaseline: Codable, Hashable, Sendable {
    public let mean: Double
    public let standardDeviation: Double

    public init(mean: Double, standardDeviation: Double) {
        self.mean = mean
        self.standardDeviation = standardDeviation
    }

    /// Z-score of `value` relative to this baseline. A floor on the deviation keeps
    /// a very stable history from turning tiny changes into huge swings.
    public func zScore(_ value: Double, minimumDeviation: Double) -> Double {
        (value - mean) / max(standardDeviation, minimumDeviation)
    }

    static func from(_ values: [Double]) -> MetricBaseline? {
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.count > 1
            ? values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
            : 0
        return MetricBaseline(mean: mean, standardDeviation: sqrt(variance))
    }
}

/// Rolling personal baseline built from previous days (today excluded).
public struct PersonalBaseline: Codable, Hashable, Sendable {
    public static let window = 28
    /// Fewer days than this and we fall back to population defaults.
    public static let minimumDays = 3

    public let hrv: MetricBaseline?
    public let restingHeartRate: MetricBaseline?
    public let respiratoryRate: MetricBaseline?
    public let daysOfData: Int

    public init(history: [DayInputs]) {
        let recent = history.sorted { $0.date > $1.date }.prefix(Self.window)
        let hrvValues = recent.compactMap(\.hrvSDNN)
        let rhrValues = recent.compactMap(\.restingHeartRate)
        let respValues = recent.compactMap(\.respiratoryRate)

        hrv = hrvValues.count >= Self.minimumDays ? .from(hrvValues) : nil
        restingHeartRate = rhrValues.count >= Self.minimumDays ? .from(rhrValues) : nil
        respiratoryRate = respValues.count >= Self.minimumDays ? .from(respValues) : nil
        daysOfData = recent.count
    }

    /// True while the app is still learning the user's normal ranges.
    public var isCalibrating: Bool { hrv == nil || restingHeartRate == nil }
}
