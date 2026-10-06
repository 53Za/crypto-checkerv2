import Foundation

/// Five heart-rate zones based on heart-rate reserve (Karvonen method).
public enum HeartRateZone: Int, CaseIterable, Codable, Comparable, Sendable {
    case rest = 0
    case zone1, zone2, zone3, zone4, zone5

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var name: String {
        switch self {
        case .rest: return "Rest"
        case .zone1: return "Easy"
        case .zone2: return "Endurance"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "Max"
        }
    }

    /// Load multiplier per minute spent in the zone (Edwards TRIMP weights).
    public var loadWeight: Double { Double(rawValue) }
}

public struct HeartRateZones: Sendable {
    public let restingHeartRate: Double
    public let maxHeartRate: Double

    public init(restingHeartRate: Double, maxHeartRate: Double) {
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = max(maxHeartRate, restingHeartRate + 1)
    }

    /// Fraction of heart-rate reserve (0 = resting, 1 = max), clamped to 0...1.
    public func reserveFraction(for bpm: Double) -> Double {
        let fraction = (bpm - restingHeartRate) / (maxHeartRate - restingHeartRate)
        return min(max(fraction, 0), 1)
    }

    public func zone(for bpm: Double) -> HeartRateZone {
        switch reserveFraction(for: bpm) {
        case ..<0.5: return .rest
        case ..<0.6: return .zone1
        case ..<0.7: return .zone2
        case ..<0.8: return .zone3
        case ..<0.9: return .zone4
        default: return .zone5
        }
    }

    /// Lower bpm bound for a zone, for display.
    public func lowerBound(of zone: HeartRateZone) -> Double {
        let fractions: [HeartRateZone: Double] = [
            .rest: 0, .zone1: 0.5, .zone2: 0.6, .zone3: 0.7, .zone4: 0.8, .zone5: 0.9
        ]
        return restingHeartRate + (fractions[zone] ?? 0) * (maxHeartRate - restingHeartRate)
    }
}
