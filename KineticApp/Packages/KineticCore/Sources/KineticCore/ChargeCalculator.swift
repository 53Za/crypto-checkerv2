import Foundation

public struct ChargeResult: Codable, Hashable, Sendable {
    /// 0–100. How ready your body is to take on Load today.
    public let score: Double
    public let hrvComponent: Double?
    public let restingHeartRateComponent: Double?
    public let sleepComponent: Double?
    /// True when respiratory rate is well above normal — often an early sign of illness.
    public let respiratoryWarning: Bool
    public let isCalibrating: Bool

    public var level: ChargeLevel { ChargeLevel(score: score) }
}

public enum ChargeLevel: String, Codable, Sendable {
    case low, moderate, high

    public init(score: Double) {
        switch score {
        case ..<34: self = .low
        case ..<67: self = .moderate
        default: self = .high
        }
    }
}

/// **Charge** (0–100): Kinetic's readiness score.
///
/// Blends three signals against *your own* baseline:
/// - HRV above your norm → more charge (50%)
/// - Resting HR below your norm → more charge (20%)
/// - Meeting your sleep need → more charge (30%)
/// Elevated respiratory rate applies a penalty.
public struct ChargeCalculator: Sendable {
    public var hrvWeight = 0.5
    public var restingHeartRateWeight = 0.2
    public var sleepWeight = 0.3

    public init() {}

    /// Maps a z-score onto 0–100 with 0σ = 50.
    static func score(fromZ z: Double) -> Double {
        100 / (1 + exp(-1.2 * z))
    }

    public func evaluate(today: DayInputs, baseline: PersonalBaseline, sleep: SleepResult?) -> ChargeResult {
        var components: [(value: Double, weight: Double)] = []

        var hrvComponent: Double?
        if let hrv = today.hrvSDNN {
            // HRV is log-normally distributed, so compare on a log scale.
            let base = baseline.hrv ?? MetricBaseline(mean: hrv, standardDeviation: 0)
            let logMean = log(max(base.mean, 1))
            let logSD = base.mean > 0 ? base.standardDeviation / base.mean : 0
            let z = (log(max(hrv, 1)) - logMean) / max(logSD, 0.08)
            hrvComponent = Self.score(fromZ: z)
            components.append((hrvComponent!, hrvWeight))
        }

        var rhrComponent: Double?
        if let rhr = today.restingHeartRate {
            let base = baseline.restingHeartRate ?? MetricBaseline(mean: rhr, standardDeviation: 0)
            let z = -base.zScore(rhr, minimumDeviation: 2)
            rhrComponent = Self.score(fromZ: z)
            components.append((rhrComponent!, restingHeartRateWeight))
        }

        var sleepComponent: Double?
        if let sleep {
            // Efficiency below 85% trims the component a little.
            let efficiencyFactor = sleep.efficiency.map { min(1, 0.7 + 0.3 * ($0 / 0.85)) } ?? 1
            sleepComponent = 100 * sleep.performance * efficiencyFactor
            components.append((sleepComponent!, sleepWeight))
        }

        var respiratoryWarning = false
        if let resp = today.respiratoryRate, let base = baseline.respiratoryRate {
            respiratoryWarning = resp - base.mean > max(1.0, 2 * base.standardDeviation)
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        var score = totalWeight > 0
            ? components.reduce(0) { $0 + $1.value * $1.weight } / totalWeight
            : 50
        if respiratoryWarning { score *= 0.85 }

        return ChargeResult(
            score: min(max(score, 0), 100),
            hrvComponent: hrvComponent,
            restingHeartRateComponent: rhrComponent,
            sleepComponent: sleepComponent,
            respiratoryWarning: respiratoryWarning,
            isCalibrating: baseline.isCalibrating
        )
    }
}
