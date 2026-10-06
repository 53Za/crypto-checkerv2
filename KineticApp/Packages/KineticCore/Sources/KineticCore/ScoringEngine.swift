import Foundation

/// The Load range Kinetic suggests for today, based on Charge.
public struct LoadTarget: Codable, Hashable, Sendable {
    public let lower: Double
    public let upper: Double

    public func contains(_ load: Double) -> Bool { load >= lower && load <= upper }
}

public struct DailyReport: Codable, Hashable, Sendable {
    public let date: Date
    public let charge: ChargeResult
    public let load: Double
    public let loadTarget: LoadTarget
    public let movement: MovementResult
    public let sleep: SleepResult?
    public let minutesInZones: [HeartRateZone: Double]
    /// Short, plain-language coaching lines for the day.
    public let insights: [String]
}

/// Combines every calculator into one report. Pure and deterministic, so it runs the
/// same on the watch, the phone and in unit tests.
public struct ScoringEngine: Sendable {
    public var profile: UserProfile
    public var load = LoadCalculator()
    public var charge = ChargeCalculator()
    public var sleep = SleepCalculator()
    public var movement = MovementCalculator()

    public init(profile: UserProfile) {
        self.profile = profile
    }

    public func zones(restingHeartRate: Double?) -> HeartRateZones {
        HeartRateZones(restingHeartRate: restingHeartRate ?? 60, maxHeartRate: profile.maxHeartRate)
    }

    public static func loadTarget(for charge: Double) -> LoadTarget {
        switch ChargeLevel(score: charge) {
        case .high: return LoadTarget(lower: 55, upper: 80)
        case .moderate: return LoadTarget(lower: 35, upper: 60)
        case .low: return LoadTarget(lower: 10, upper: 35)
        }
    }

    /// Builds today's report.
    /// - Parameters:
    ///   - today: Today's inputs (may be a partial day).
    ///   - history: Previous days, any order. Used for baselines and yesterday's load/sleep debt.
    ///   - currentHour: Hour of day for partial-day movement scoring; 24 for a finished day.
    public func report(today: DayInputs, history: [DayInputs], currentHour: Int = 24) -> DailyReport {
        let previous = history.filter { $0.date < today.date }.sorted { $0.date > $1.date }
        let baseline = PersonalBaseline(history: previous)
        let yesterday = previous.first

        let yesterdayLoad = yesterday.map {
            load.load(samples: $0.heartRateSamples, zones: zones(restingHeartRate: $0.restingHeartRate))
        } ?? 0
        let yesterdayDebt = yesterday.flatMap { day -> Double? in
            guard let hours = day.sleepHours else { return nil }
            return sleep.evaluate(sleepHours: hours, inBedHours: day.inBedHours, profile: profile,
                                  previousDebtHours: 0, previousLoad: 0).debtHours
        } ?? 0

        let sleepResult = today.sleepHours.map {
            sleep.evaluate(sleepHours: $0, inBedHours: today.inBedHours, profile: profile,
                           previousDebtHours: yesterdayDebt, previousLoad: yesterdayLoad)
        }
        let chargeResult = charge.evaluate(today: today, baseline: baseline, sleep: sleepResult)

        let todayZones = zones(restingHeartRate: today.restingHeartRate ?? baseline.restingHeartRate?.mean)
        let zoneMinutes = load.minutesInZones(samples: today.heartRateSamples, zones: todayZones)
        let todayLoad = load.load(fromTrimp: zoneMinutes.reduce(0) { $0 + $1.value * $1.key.loadWeight })
        let target = Self.loadTarget(for: chargeResult.score)
        let movementResult = movement.evaluate(hourlySteps: today.hourlySteps, profile: profile, upToHour: currentHour)

        return DailyReport(
            date: today.date,
            charge: chargeResult,
            load: todayLoad,
            loadTarget: target,
            movement: movementResult,
            sleep: sleepResult,
            minutesInZones: zoneMinutes,
            insights: insights(charge: chargeResult, load: todayLoad, target: target,
                               movement: movementResult, sleep: sleepResult, baseline: baseline)
        )
    }

    func insights(
        charge: ChargeResult,
        load: Double,
        target: LoadTarget,
        movement: MovementResult,
        sleep: SleepResult?,
        baseline: PersonalBaseline
    ) -> [String] {
        var lines: [String] = []
        if charge.isCalibrating {
            lines.append("Still learning your baseline (\(baseline.daysOfData)/\(PersonalBaseline.minimumDays)+ days). Scores will sharpen soon.")
        }
        if charge.respiratoryWarning {
            lines.append("Breathing rate is higher than usual. Consider an easy day — this can be an early sign of illness.")
        }
        switch charge.level {
        case .high: lines.append("Fully charged. A good day to push hard.")
        case .moderate: lines.append("Moderately charged. Train, but keep the intensity in check.")
        case .low: lines.append("Low charge. Prioritise recovery: walk, stretch, sleep early.")
        }
        if load > target.upper {
            lines.append("You've passed today's Load target. Extra effort now will cost tomorrow's Charge.")
        } else if load < target.lower {
            lines.append("About \(Int((target.lower - load).rounded())) Load to reach today's target.")
        } else {
            lines.append("You're in today's Load target zone.")
        }
        if movement.longestSedentaryStreakHours >= 3 {
            lines.append("Longest still stretch: \(movement.longestSedentaryStreakHours)h. Short walks every hour lift your Movement score.")
        }
        if let sleep, sleep.debtHours >= 0.75 {
            let minutes = Int((sleep.debtHours * 60).rounded())
            lines.append("You're \(minutes) min short on sleep. Aim for \(String(format: "%.1f", sleep.needHours))h tonight.")
        }
        return lines
    }
}
