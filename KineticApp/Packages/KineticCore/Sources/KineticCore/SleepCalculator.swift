import Foundation

public struct SleepResult: Codable, Hashable, Sendable {
    /// Hours of sleep you needed last night (base need + debt + yesterday's load).
    public let needHours: Double
    public let actualHours: Double
    /// actual / need, capped at 1.
    public let performance: Double
    /// asleep / in bed, when time in bed is known.
    public let efficiency: Double?
    /// How far short of need you were (0 when you met it).
    public let debtHours: Double
}

/// Works out how much sleep you needed and how well you met it.
public struct SleepCalculator: Sendable {
    /// Debt carried from the previous night is capped so one bad night can't demand 12 hours.
    public var maxCarriedDebtHours = 1.5
    /// Extra sleep needed after a maximal (100) Load day.
    public var maxLoadAdjustmentHours = 0.75

    public init() {}

    public func sleepNeed(profile: UserProfile, previousDebtHours: Double, previousLoad: Double) -> Double {
        let debt = min(max(previousDebtHours, 0), maxCarriedDebtHours) * 0.5
        let loadAdjustment = min(max(previousLoad, 0), 100) / 100 * maxLoadAdjustmentHours
        return profile.baseSleepNeedHours + debt + loadAdjustment
    }

    public func evaluate(
        sleepHours: Double,
        inBedHours: Double?,
        profile: UserProfile,
        previousDebtHours: Double,
        previousLoad: Double
    ) -> SleepResult {
        let need = sleepNeed(profile: profile, previousDebtHours: previousDebtHours, previousLoad: previousLoad)
        let actual = max(sleepHours, 0)
        let efficiency = inBedHours.flatMap { $0 > 0 ? min(actual / $0, 1) : nil }
        return SleepResult(
            needHours: need,
            actualHours: actual,
            performance: min(actual / need, 1),
            efficiency: efficiency,
            debtHours: max(need - actual, 0)
        )
    }
}
