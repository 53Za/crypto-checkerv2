import Foundation
import HealthKit
import CoreMotion
import KineticCore

/// Runs a live session on the watch: an HKWorkoutSession for heart rate & calories,
/// plus raw accelerometer data for Kinetic's motion-intensity and cadence readout.
final class WorkoutManager: NSObject, ObservableObject {
    enum State { case idle, running, paused, ended }

    @Published private(set) var state: State = .idle
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var zone: HeartRateZone = .rest
    @Published private(set) var sessionLoad: Double = 0
    @Published private(set) var motion: MotionSnapshot?
    @Published private(set) var secondsByIntensity: [MotionIntensity: TimeInterval] = [:]
    @Published private(set) var minutesInZones: [HeartRateZone: Double] = [:]
    @Published private(set) var startDate: Date?
    @Published private(set) var activity: HKWorkoutActivityType = .other
    @Published var errorMessage: String?

    private let healthStore = HealthDataProvider.shared.store
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kinetic.motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var analyzer = MotionIntensityAnalyzer(windowDuration: 5)

    private var samples: [HeartRateSample] = []
    private var zones = HeartRateZones(restingHeartRate: 60, maxHeartRate: 190)
    private let loadCalculator = LoadCalculator()

    /// Elapsed active time, excluding pauses.
    func elapsedTime(at date: Date) -> TimeInterval {
        builder?.elapsedTime(at: date) ?? 0
    }

    // MARK: - Control

    func start(_ activity: HKWorkoutActivityType, profile: UserProfile, restingHeartRate: Double?) {
        zones = HeartRateZones(restingHeartRate: restingHeartRate ?? 60, maxHeartRate: profile.maxHeartRate)
        samples = []
        analyzer.reset()
        heartRate = 0
        activeEnergy = 0
        sessionLoad = 0
        motion = nil
        secondsByIntensity = [:]
        minutesInZones = [:]
        self.activity = activity

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = activity == .running || activity == .walking || activity == .cycling ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error { self?.errorMessage = error.localizedDescription }
                }
            }
            startDate = start
            startMotionUpdates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePause() {
        guard let session else { return }
        state == .running ? session.pause() : session.resume()
    }

    func end() {
        session?.end()
    }

    func reset() {
        session = nil
        builder = nil
        startDate = nil
        state = .idle
    }

    // MARK: - Motion

    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 25.0
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            // `analyzer` is only touched on the serial motion queue.
            guard let snapshot = self.analyzer.add(
                x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z,
                timestamp: data.timestamp
            ) else { return }
            let totals = self.analyzer.secondsByIntensity
            DispatchQueue.main.async {
                guard self.state == .running else { return }
                self.motion = snapshot
                self.secondsByIntensity = totals
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopAccelerometerUpdates()
    }

    // MARK: - Heart rate

    private func handle(statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            guard let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) else { return }
            heartRate = value
            zone = zones.zone(for: value)
            samples.append(HeartRateSample(date: Date(), bpm: value))
            minutesInZones = loadCalculator.minutesInZones(samples: samples, zones: zones)
            sessionLoad = loadCalculator.load(samples: samples, zones: zones)
        case HKQuantityType(.activeEnergyBurned):
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        default:
            break
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running: self.state = .running
            case .paused: self.state = .paused
            case .ended: self.state = .ended
            default: break
            }
        }
        guard toState == .ended else { return }
        stopMotionUpdates()
        builder?.endCollection(withEnd: date) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, error in
                DispatchQueue.main.async {
                    if let error { self?.errorMessage = error.localizedDescription }
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            DispatchQueue.main.async { self.handle(statistics: statistics) }
        }
    }
}

extension HKWorkoutActivityType: Identifiable {
    public var id: UInt { rawValue }

    static let kineticChoices: [HKWorkoutActivityType] = [
        .running, .walking, .cycling, .functionalStrengthTraining, .highIntensityIntervalTraining, .yoga, .other
    ]

    var displayName: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        default: return "Free Move"
        }
    }

    var symbol: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .functionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "bolt.heart.fill"
        case .yoga: return "figure.yoga"
        default: return "figure.mixed.cardio"
        }
    }
}
