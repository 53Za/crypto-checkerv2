import XCTest
@testable import KineticCore

final class HeartRateZoneTests: XCTestCase {
    func testZonesUseHeartRateReserve() {
        let zones = HeartRateZones(restingHeartRate: 60, maxHeartRate: 190)
        XCTAssertEqual(zones.zone(for: 70), .rest)
        XCTAssertEqual(zones.zone(for: 60 + 0.55 * 130), .zone1)
        XCTAssertEqual(zones.zone(for: 60 + 0.75 * 130), .zone3)
        XCTAssertEqual(zones.zone(for: 200), .zone5)
        XCTAssertEqual(zones.lowerBound(of: .zone4), 60 + 0.8 * 130, accuracy: 0.001)
    }

    func testMaxHeartRateFromAge() {
        XCTAssertEqual(UserProfile(age: 40).maxHeartRate, 180, accuracy: 0.001)
        XCTAssertEqual(UserProfile(age: 40, maxHeartRateOverride: 195).maxHeartRate, 195)
    }
}

final class LoadTests: XCTestCase {
    let zones = HeartRateZones(restingHeartRate: 60, maxHeartRate: 190)

    func samples(bpm: Double, minutes: Int, start: Date = Date(timeIntervalSince1970: 0)) -> [HeartRateSample] {
        (0...minutes).map { HeartRateSample(date: start.addingTimeInterval(Double($0) * 60), bpm: bpm) }
    }

    func testRestingDayHasNoLoad() {
        XCTAssertEqual(LoadCalculator().load(samples: samples(bpm: 65, minutes: 600), zones: zones), 0)
    }

    func testTempoSessionLandsMidRange() {
        // 45 min at 75% HRR = zone 3 → TRIMP 135.
        let load = LoadCalculator().load(samples: samples(bpm: 60 + 0.75 * 130, minutes: 45), zones: zones)
        XCTAssertEqual(load, 100 * (1 - exp(-135.0 / 150)), accuracy: 0.01)
        XCTAssertTrue((55...65).contains(load))
    }

    func testLoadSaturates() {
        let load = LoadCalculator().load(samples: samples(bpm: 185, minutes: 300), zones: zones)
        XCTAssertLessThan(load, 100)
        XCTAssertGreaterThan(load, 99)
    }

    func testLongGapsAreCapped() {
        let s = [
            HeartRateSample(date: Date(timeIntervalSince1970: 0), bpm: 170),
            HeartRateSample(date: Date(timeIntervalSince1970: 3600), bpm: 170)
        ]
        let minutes = LoadCalculator().minutesInZones(samples: s, zones: zones)
        XCTAssertEqual(minutes.values.reduce(0, +), 5, accuracy: 0.001)
    }
}

final class SleepTests: XCTestCase {
    func testNeedIncludesDebtAndLoad() {
        let need = SleepCalculator().sleepNeed(profile: UserProfile(baseSleepNeedHours: 8), previousDebtHours: 1, previousLoad: 100)
        XCTAssertEqual(need, 8 + 0.5 + 0.75, accuracy: 0.001)
    }

    func testDebtIsCapped() {
        let need = SleepCalculator().sleepNeed(profile: UserProfile(baseSleepNeedHours: 8), previousDebtHours: 6, previousLoad: 0)
        XCTAssertEqual(need, 8.75, accuracy: 0.001)
    }

    func testPerformanceAndEfficiency() {
        let result = SleepCalculator().evaluate(sleepHours: 6, inBedHours: 8, profile: UserProfile(),
                                                previousDebtHours: 0, previousLoad: 0)
        XCTAssertEqual(result.performance, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.efficiency ?? 0, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.debtHours, 2, accuracy: 0.001)
    }
}

final class ChargeTests: XCTestCase {
    func history(days: Int, hrv: Double, rhr: Double) -> [DayInputs] {
        (1...days).map { (i: Int) -> DayInputs in
            let n = Double(i)
            let restingHR: Double = rhr + Double(i % 3) - 1
            let variability: Double = hrv + Double(i % 5) * 2 - 4
            let breathing: Double = 14 + Double(i % 2) * 0.2
            return DayInputs(date: Date(timeIntervalSince1970: -n * 86_400),
                             restingHeartRate: restingHR, hrvSDNN: variability, respiratoryRate: breathing)
        }
    }

    func testAboveBaselineIsHighCharge() {
        let baseline = PersonalBaseline(history: history(days: 14, hrv: 50, rhr: 55))
        let today = DayInputs(date: Date(timeIntervalSince1970: 0), restingHeartRate: 51, hrvSDNN: 70)
        let full = SleepResult(needHours: 8, actualHours: 8, performance: 1, efficiency: 0.95, debtHours: 0)
        let result = ChargeCalculator().evaluate(today: today, baseline: baseline, sleep: full)
        XCTAssertEqual(result.level, .high)
        XCTAssertFalse(result.isCalibrating)
    }

    func testBelowBaselineIsLowCharge() {
        let baseline = PersonalBaseline(history: history(days: 14, hrv: 50, rhr: 55))
        let today = DayInputs(date: Date(timeIntervalSince1970: 0), restingHeartRate: 62, hrvSDNN: 32)
        let poor = SleepResult(needHours: 8, actualHours: 4, performance: 0.5, efficiency: 0.7, debtHours: 4)
        let result = ChargeCalculator().evaluate(today: today, baseline: baseline, sleep: poor)
        XCTAssertEqual(result.level, .low)
    }

    func testRespiratoryWarningPenalises() {
        let baseline = PersonalBaseline(history: history(days: 14, hrv: 50, rhr: 55))
        let normal = DayInputs(date: Date(timeIntervalSince1970: 0), restingHeartRate: 55, hrvSDNN: 50, respiratoryRate: 14)
        var sick = normal
        sick.respiratoryRate = 17
        let calc = ChargeCalculator()
        let a = calc.evaluate(today: normal, baseline: baseline, sleep: nil)
        let b = calc.evaluate(today: sick, baseline: baseline, sleep: nil)
        XCTAssertTrue(b.respiratoryWarning)
        XCTAssertLessThan(b.score, a.score)
    }

    func testCalibratingWithoutHistory() {
        let today = DayInputs(date: Date(), restingHeartRate: 55, hrvSDNN: 50)
        let result = ChargeCalculator().evaluate(today: today, baseline: PersonalBaseline(history: []), sleep: nil)
        XCTAssertTrue(result.isCalibrating)
        XCTAssertEqual(result.score, 50, accuracy: 0.001)
    }
}

final class MovementTests: XCTestCase {
    let profile = UserProfile(dailyStepGoal: 8_000, wakeHour: 7, bedHour: 23)

    func testSpreadBeatsOneBigBlock() {
        var spread = Array(repeating: 0, count: 24)
        for hour in 7..<23 { spread[hour] = 500 }   // 8,000 steps across the day
        var block = Array(repeating: 0, count: 24)
        block[7] = 8_000                             // 8,000 steps in one go

        let calc = MovementCalculator()
        let a = calc.evaluate(hourlySteps: spread, profile: profile)
        let b = calc.evaluate(hourlySteps: block, profile: profile)
        XCTAssertEqual(a.score, 100, accuracy: 0.001)
        XCTAssertEqual(b.longestSedentaryStreakHours, 15)
        XCTAssertLessThan(b.score, 50)
    }

    func testPartialDayOnlyCountsElapsedHours() {
        var steps = Array(repeating: 0, count: 24)
        steps[7] = 400; steps[8] = 400
        let result = MovementCalculator().evaluate(hourlySteps: steps, profile: profile, upToHour: 9)
        XCTAssertEqual(result.awakeHoursElapsed, 2)
        XCTAssertEqual(result.activeHours, 2)
        XCTAssertEqual(result.longestSedentaryStreakHours, 0)
    }

    func testLateBedtimeWrapsMidnight() {
        let night = UserProfile(wakeHour: 10, bedHour: 2)
        XCTAssertEqual(night.awakeHours.count, 16)
        XCTAssertTrue(night.awakeHours.contains(1))
        let partial = MovementCalculator().evaluate(hourlySteps: Array(repeating: 0, count: 24), profile: night, upToHour: 12)
        XCTAssertEqual(partial.awakeHoursElapsed, 2)
    }
}

final class MotionTests: XCTestCase {
    func testStillWristIsStill() {
        var analyzer = MotionIntensityAnalyzer(windowDuration: 5)
        var snapshot: MotionSnapshot?
        for i in 0...125 {
            snapshot = analyzer.add(x: 0, y: 0, z: -1, timestamp: Double(i) / 25) ?? snapshot
        }
        XCTAssertEqual(snapshot?.intensity, .still)
        XCTAssertEqual(snapshot?.cadence ?? -1, 0, accuracy: 0.001)
    }

    func testRunningCadenceIsDetected() {
        // 2.7 Hz oscillation ≈ 162 strides/min with large amplitude.
        var analyzer = MotionIntensityAnalyzer(windowDuration: 10)
        var snapshot: MotionSnapshot?
        let rate = 50.0
        for i in 0...Int(10 * rate) {
            let t = Double(i) / rate
            let z = -1 - 0.9 * sin(2 * .pi * 2.7 * t)
            snapshot = analyzer.add(x: 0.1, y: 0.1, z: z, timestamp: t) ?? snapshot
        }
        XCTAssertNotNil(snapshot)
        XCTAssertGreaterThanOrEqual(snapshot!.intensity, .moderate)
        XCTAssertEqual(snapshot!.cadence, 162, accuracy: 8)
        XCTAssertEqual(analyzer.secondsByIntensity.values.reduce(0, +), 10, accuracy: 0.1)
    }
}

final class ScoringEngineTests: XCTestCase {
    func testReportUsesYesterdayLoadForSleepNeed() {
        let day: TimeInterval = 86_400
        let base = Date(timeIntervalSince1970: 30 * day)
        var history: [DayInputs] = (1...10).map {
            DayInputs(date: base.addingTimeInterval(-Double($0) * day), restingHeartRate: 55, hrvSDNN: 50, sleepHours: 8)
        }
        // Yesterday: a hard 60-minute session at threshold.
        let start = base.addingTimeInterval(-day + 18 * 3600)
        history[0].heartRateSamples = (0...60).map {
            HeartRateSample(date: start.addingTimeInterval(Double($0) * 60), bpm: 172)
        }

        let engine = ScoringEngine(profile: UserProfile(age: 30, baseSleepNeedHours: 8))
        let today = DayInputs(date: base, restingHeartRate: 55, hrvSDNN: 50, sleepHours: 8)
        let report = engine.report(today: today, history: history)

        XCTAssertGreaterThan(report.sleep!.needHours, 8.5)
        XCTAssertLessThan(report.sleep!.performance, 1)
        XCTAssertEqual(report.load, 0)
        XCTAssertFalse(report.insights.isEmpty)
    }

    func testLoadTargetFollowsCharge() {
        XCTAssertEqual(ScoringEngine.loadTarget(for: 90), LoadTarget(lower: 55, upper: 80))
        XCTAssertEqual(ScoringEngine.loadTarget(for: 50), LoadTarget(lower: 35, upper: 60))
        XCTAssertEqual(ScoringEngine.loadTarget(for: 10), LoadTarget(lower: 10, upper: 35))
    }

    func testReportIsCodable() throws {
        let report = ScoringEngine(profile: UserProfile()).report(today: DayInputs(date: Date(timeIntervalSince1970: 0)), history: [])
        let data = try JSONEncoder().encode(report)
        XCTAssertEqual(try JSONDecoder().decode(DailyReport.self, from: data), report)
    }
}
