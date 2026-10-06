import SwiftUI
import HealthKit
import KineticCore

struct StartSessionView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var model: ReportModel

    var body: some View {
        List(HKWorkoutActivityType.kineticChoices) { activity in
            Button {
                workoutManager.start(activity, profile: profileStore.profile,
                                     restingHeartRate: model.restingHeartRate)
            } label: {
                Label(activity.displayName, systemImage: activity.symbol)
            }
        }
        .navigationTitle("Track")
    }
}

/// Live readout while a session runs: time, heart rate & zone, live Load, and
/// accelerometer-based motion intensity with cadence.
struct LiveSessionView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.format(workoutManager.elapsedTime(at: context.date)))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)

                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Spacer()
                    Text(workoutManager.zone.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.zone(workoutManager.zone).opacity(0.3), in: Capsule())
                }

                Gauge(value: workoutManager.sessionLoad, in: 0...100) {
                    Text("Load")
                } currentValueLabel: {
                    Text("\(Int(workoutManager.sessionLoad))")
                }
                .gaugeStyle(.accessoryLinear)
                .tint(Theme.load)

                HStack {
                    Label(workoutManager.motion?.intensity.name ?? "—", systemImage: "waveform.path.ecg")
                    Spacer()
                    Text("\(Int(workoutManager.motion?.cadence ?? 0)) spm")
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(Theme.movement)

                HStack {
                    Button {
                        workoutManager.togglePause()
                    } label: {
                        Image(systemName: workoutManager.state == .paused ? "play.fill" : "pause.fill")
                    }
                    .tint(.yellow)
                    Button(role: .destructive) {
                        workoutManager.end()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(workoutManager.activity.displayName)
        .navigationBarBackButtonHidden(true)
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

struct SessionSummaryView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var model: ReportModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Load \(Int(workoutManager.sessionLoad))")
                    .font(.headline)
                    .foregroundStyle(Theme.load)
                Text("\(Int(workoutManager.activeEnergy)) kcal")
                    .font(.caption)

                Text("Heart-rate zones").font(.caption2).foregroundStyle(.secondary)
                ForEach(HeartRateZone.allCases.reversed(), id: \.self) { zone in
                    row(zone.name, minutes: workoutManager.minutesInZones[zone] ?? 0, color: Theme.zone(zone))
                }

                Text("Motion").font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(MotionIntensity.allCases.reversed(), id: \.self) { intensity in
                    row(intensity.name, minutes: (workoutManager.secondsByIntensity[intensity] ?? 0) / 60, color: Theme.movement)
                }

                Button("Done") {
                    workoutManager.reset()
                    Task { await model.refresh(profile: profileStore.profile) }
                }
                .padding(.top, 6)
            }
        }
        .navigationTitle("Summary")
        .navigationBarBackButtonHidden(true)
    }

    private func row(_ title: String, minutes: Double, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption2)
            Spacer()
            Text("\(Int(minutes.rounded())) min").font(.caption2).monospacedDigit()
        }
    }
}
