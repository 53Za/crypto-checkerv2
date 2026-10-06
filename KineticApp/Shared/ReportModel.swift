import Foundation
import KineticCore

/// Loads HealthKit data and produces today's report plus a short trend.
@MainActor
final class ReportModel: ObservableObject {
    @Published private(set) var today: DailyReport?
    /// Oldest first, today last.
    @Published private(set) var trend: [DailyReport] = []
    /// Latest known resting heart rate, used to set live heart-rate zones.
    @Published private(set) var restingHeartRate: Double?
    /// Today's steps per hour (index 0 = midnight), for the hour strip.
    @Published private(set) var todayHourlySteps: [Int] = Array(repeating: 0, count: 24)
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let health = HealthDataProvider.shared
    /// Days of trend to compute (each needs that day's heart-rate samples).
    let trendDays: Int

    init(trendDays: Int = 1) {
        self.trendDays = max(trendDays, 1)
    }

    func refresh(profile: UserProfile) async {
        guard health.isAvailable else {
            errorMessage = "Health data isn't available on this device."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await health.requestAuthorization()
            let now = Date()
            // Baseline window plus enough extra days for every trend day to have its own baseline.
            let (todayInputs, history) = try await health.inputs(
                endingOn: now,
                historyDays: PersonalBaseline.window + trendDays,
                heartRateDays: trendDays
            )
            let engine = ScoringEngine(profile: profile)
            let hour = Calendar.current.component(.hour, from: now)

            var reports: [DailyReport] = []
            for offset in stride(from: trendDays - 1, through: 1, by: -1) {
                let day = history[offset - 1]
                let earlier = Array(history[offset...])
                reports.append(engine.report(today: day, history: earlier))
            }
            let todayReport = engine.report(today: todayInputs, history: history, currentHour: hour)
            reports.append(todayReport)

            today = todayReport
            restingHeartRate = todayInputs.restingHeartRate ?? history.lazy.compactMap(\.restingHeartRate).first
            todayHourlySteps = todayInputs.hourlySteps
            trend = reports
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
