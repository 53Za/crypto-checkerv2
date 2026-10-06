import Foundation
import HealthKit
import KineticCore

/// Reads everything Kinetic needs from HealthKit and turns it into `DayInputs`.
/// Shared by the watch and iPhone apps.
final class HealthDataProvider {
    static let shared = HealthDataProvider()

    let store = HKHealthStore()

    private let bpm = HKUnit.count().unitDivided(by: .minute())
    private let milliseconds = HKUnit.secondUnit(with: .milli)
    private let calendar = Calendar.current

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType()
    ]

    static let shareTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned)
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }

    // MARK: - Days

    /// Inputs for `day` and the `historyDays` days before it (most recent first).
    /// Heart-rate samples are only loaded for the newest `heartRateDays` days, because
    /// baselines don't need them and they are by far the largest query.
    func inputs(endingOn day: Date, historyDays: Int, heartRateDays: Int) async throws -> (today: DayInputs, history: [DayInputs]) {
        let today = try await dayInputs(for: day, includeHeartRate: true)
        var history: [DayInputs] = []
        for offset in 1...max(historyDays, 1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            history.append(try await dayInputs(for: date, includeHeartRate: offset <= heartRateDays))
        }
        return (today, history)
    }

    func dayInputs(for day: Date, includeHeartRate: Bool) async throws -> DayInputs {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        // The night that ends on `day`: 6pm the evening before until noon.
        let nightStart = calendar.date(byAdding: .hour, value: -6, to: start)!
        let nightEnd = calendar.date(byAdding: .hour, value: 12, to: start)!

        async let rhr = average(.restingHeartRate, unit: bpm, from: start, to: end)
        async let hrv = average(.heartRateVariabilitySDNN, unit: milliseconds, from: nightStart, to: nightEnd)
        async let resp = average(.respiratoryRate, unit: bpm, from: nightStart, to: nightEnd)
        async let sleep = sleepHours(from: nightStart, to: nightEnd)
        async let steps = hourlySteps(from: start, to: end)
        async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        let heartRate = includeHeartRate ? try await heartRateSamples(from: start, to: end) : []

        let sleepResult = try await sleep
        return DayInputs(
            date: start,
            restingHeartRate: try await rhr,
            hrvSDNN: try await hrv,
            respiratoryRate: try await resp,
            sleepHours: sleepResult.asleep,
            inBedHours: sleepResult.inBed,
            heartRateSamples: heartRate,
            hourlySteps: try await steps,
            activeEnergyKcal: try await energy
        )
    }

    // MARK: - Queries

    private func predicate(from start: Date, to end: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate(from: start, to: end)),
            options: .discreteAverage
        )
        return try await query.result(for: store)?.averageQuantity()?.doubleValue(for: unit)
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate(from: start, to: end)),
            options: .cumulativeSum
        )
        return try await query.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
    }

    func heartRateSamples(from start: Date, to end: Date) async throws -> [HeartRateSample] {
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate(from: start, to: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await query.result(for: store).map {
            HeartRateSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: bpm))
        }
    }

    func hourlySteps(from start: Date, to end: Date) async throws -> [Int] {
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate(from: start, to: end)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(hour: 1)
        )
        var steps = Array(repeating: 0, count: 24)
        let collection = try await query.result(for: store)
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let hour = self.calendar.component(.hour, from: statistics.startDate)
            let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
            if steps.indices.contains(hour) { steps[hour] += Int(count) }
        }
        return steps
    }

    /// Hours asleep and in bed. Phone and watch can both write overlapping sleep samples,
    /// so intervals are merged before summing to avoid double counting.
    private func sleepHours(from start: Date, to end: Date) async throws -> (asleep: Double?, inBed: Double?) {
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate(from: start, to: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await query.result(for: store)
        guard !samples.isEmpty else { return (nil, nil) }

        let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let asleep = samples.filter { asleepValues.contains($0.value) }.map { ($0.startDate, $0.endDate) }
        let everything = samples.map { ($0.startDate, $0.endDate) }

        let asleepHours = Self.mergedDuration(asleep) / 3600
        return (asleepHours > 0 ? asleepHours : nil, Self.mergedDuration(everything) / 3600)
    }

    static func mergedDuration(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var current: (Date, Date)?
        for interval in sorted {
            if let c = current, interval.0 <= c.1 {
                current = (c.0, max(c.1, interval.1))
            } else {
                if let c = current { total += c.1.timeIntervalSince(c.0) }
                current = interval
            }
        }
        if let c = current { total += c.1.timeIntervalSince(c.0) }
        return total
    }
}
