import Foundation

public struct MovementResult: Codable, Hashable, Sendable {
    /// 0–100. Rewards moving *often*, not just moving a lot once.
    public let score: Double
    public let totalSteps: Int
    /// Awake hours with at least `activeHourStepThreshold` steps.
    public let activeHours: Int
    public let awakeHoursElapsed: Int
    /// Longest run of consecutive awake hours below the threshold.
    public let longestSedentaryStreakHours: Int
}

/// **Movement** (0–100): Kinetic's all-day movement score — the part WHOOP doesn't measure.
///
/// Strain-style scores only see heart rate, so an hour in the gym followed by ten hours
/// in a chair still looks like a great day. Movement looks at how your steps are *spread*:
/// - 45% step volume vs your goal
/// - 35% share of awake hours where you moved
/// - 20% penalty for the longest sedentary streak
public struct MovementCalculator: Sendable {
    public var activeHourStepThreshold = 250
    /// A sedentary streak this long (or longer) removes the whole streak component.
    public var maxPenalisedStreakHours = 6

    public init() {}

    /// - Parameter upToHour: Only hours before this are scored, so a live score doesn't
    ///   punish you for hours that haven't happened yet. Pass 24 for a finished day.
    public func evaluate(hourlySteps: [Int], profile: UserProfile, upToHour: Int = 24) -> MovementResult {
        let steps = hourlySteps.count == 24 ? hourlySteps : Array(repeating: 0, count: 24)
        // For a partial day, early-morning hours after a past-midnight bedtime belong to
        // the previous night, so only hours between waking and `upToHour` count.
        let elapsedAwake = upToHour >= 24
            ? profile.awakeHours
            : profile.awakeHours.filter { $0 >= profile.wakeHour && $0 < upToHour }

        var active = 0
        var streak = 0
        var longestStreak = 0
        for hour in elapsedAwake {
            if steps[hour] >= activeHourStepThreshold {
                active += 1
                streak = 0
            } else {
                streak += 1
                longestStreak = max(longestStreak, streak)
            }
        }

        let total = steps.reduce(0, +)
        let volume = profile.dailyStepGoal > 0 ? min(Double(total) / Double(profile.dailyStepGoal), 1) : 1
        let spread = elapsedAwake.isEmpty ? 1 : Double(active) / Double(elapsedAwake.count)
        let streakScore = 1 - Double(min(longestStreak, maxPenalisedStreakHours)) / Double(maxPenalisedStreakHours)

        let score = 100 * (0.45 * volume + 0.35 * spread + 0.20 * streakScore)
        return MovementResult(
            score: min(max(score, 0), 100),
            totalSteps: total,
            activeHours: active,
            awakeHoursElapsed: elapsedAwake.count,
            longestSedentaryStreakHours: longestStreak
        )
    }
}
