import Foundation

/// A single heart-rate reading.
public struct HeartRateSample: Codable, Hashable, Sendable {
    public let date: Date
    public let bpm: Double

    public init(date: Date, bpm: Double) {
        self.date = date
        self.bpm = bpm
    }
}

/// Personal settings that drive the scoring models.
public struct UserProfile: Codable, Hashable, Sendable {
    public var age: Int
    /// Measured max heart rate. When nil, it is estimated from age (Tanaka: 208 - 0.7 × age).
    public var maxHeartRateOverride: Double?
    public var dailyStepGoal: Int
    /// Baseline sleep need in hours before debt/load adjustments.
    public var baseSleepNeedHours: Double
    /// The hours of the day (0–23) the user is normally awake; used for movement scoring and nudges.
    public var wakeHour: Int
    public var bedHour: Int

    public init(
        age: Int = 30,
        maxHeartRateOverride: Double? = nil,
        dailyStepGoal: Int = 8_000,
        baseSleepNeedHours: Double = 8.0,
        wakeHour: Int = 7,
        bedHour: Int = 23
    ) {
        self.age = age
        self.maxHeartRateOverride = maxHeartRateOverride
        self.dailyStepGoal = dailyStepGoal
        self.baseSleepNeedHours = baseSleepNeedHours
        self.wakeHour = wakeHour
        self.bedHour = bedHour
    }

    public var maxHeartRate: Double {
        maxHeartRateOverride ?? (208.0 - 0.7 * Double(age))
    }

    /// Hours considered "awake" for movement scoring, handling a bedtime past midnight.
    public var awakeHours: [Int] {
        if bedHour > wakeHour { return Array(wakeHour..<bedHour) }
        return Array(wakeHour..<24) + Array(0..<bedHour)
    }
}

/// Everything the scoring engine needs for one calendar day. Populated from HealthKit by the apps.
public struct DayInputs: Codable, Hashable, Sendable {
    public var date: Date
    public var restingHeartRate: Double?
    /// Heart-rate variability (SDNN, ms) as reported by Apple Watch.
    public var hrvSDNN: Double?
    /// Respiratory rate during sleep (breaths/min), if available.
    public var respiratoryRate: Double?
    /// Total time asleep for the night that ended on this day, in hours.
    public var sleepHours: Double?
    /// Time in bed for that night, in hours (used for sleep efficiency).
    public var inBedHours: Double?
    public var heartRateSamples: [HeartRateSample]
    /// Steps for each hour of the day, index 0 = midnight. Must have 24 entries when present.
    public var hourlySteps: [Int]
    public var activeEnergyKcal: Double?

    public init(
        date: Date,
        restingHeartRate: Double? = nil,
        hrvSDNN: Double? = nil,
        respiratoryRate: Double? = nil,
        sleepHours: Double? = nil,
        inBedHours: Double? = nil,
        heartRateSamples: [HeartRateSample] = [],
        hourlySteps: [Int] = Array(repeating: 0, count: 24),
        activeEnergyKcal: Double? = nil
    ) {
        self.date = date
        self.restingHeartRate = restingHeartRate
        self.hrvSDNN = hrvSDNN
        self.respiratoryRate = respiratoryRate
        self.sleepHours = sleepHours
        self.inBedHours = inBedHours
        self.heartRateSamples = heartRateSamples
        self.hourlySteps = hourlySteps
        self.activeEnergyKcal = activeEnergyKcal
    }

    public var totalSteps: Int { hourlySteps.reduce(0, +) }
}
