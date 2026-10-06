import Foundation

/// Cardiovascular **Load** (0–100): how much stress the day put on your heart.
///
/// Time in each heart-rate-reserve zone is weighted (Edwards TRIMP) and then mapped
/// onto a saturating 0–100 curve, so going from 80 → 90 takes far more work than 20 → 30.
public struct LoadCalculator: Sendable {
    /// TRIMP value at which Load reaches ~63. Tuned so a solid 45-minute tempo session lands around 55–65.
    public var saturationConstant: Double = 150
    /// Gaps longer than this between samples are not counted (watch off wrist, etc).
    public var maxGap: TimeInterval = 5 * 60

    public init() {}

    public func minutesInZones(samples: [HeartRateSample], zones: HeartRateZones) -> [HeartRateZone: Double] {
        var result: [HeartRateZone: Double] = [:]
        let sorted = samples.sorted { $0.date < $1.date }
        guard sorted.count > 1 else { return result }
        for (current, next) in zip(sorted, sorted.dropFirst()) {
            let gap = next.date.timeIntervalSince(current.date)
            guard gap > 0 else { continue }
            let minutes = min(gap, maxGap) / 60
            result[zones.zone(for: current.bpm), default: 0] += minutes
        }
        return result
    }

    public func trimp(samples: [HeartRateSample], zones: HeartRateZones) -> Double {
        minutesInZones(samples: samples, zones: zones)
            .reduce(0) { $0 + $1.value * $1.key.loadWeight }
    }

    public func load(fromTrimp trimp: Double) -> Double {
        guard trimp > 0 else { return 0 }
        return 100 * (1 - exp(-trimp / saturationConstant))
    }

    public func load(samples: [HeartRateSample], zones: HeartRateZones) -> Double {
        load(fromTrimp: trimp(samples: samples, zones: zones))
    }
}
