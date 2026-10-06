import SwiftUI
import KineticCore

/// Today's Movement score with an hour-by-hour strip of when you moved.
struct MovementView: View {
    @EnvironmentObject private var model: ReportModel
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let movement = model.today?.movement {
                    ScoreRing(value: movement.score, maxValue: 100, color: Theme.movement, title: "Movement")
                        .frame(height: 70)
                    Text("\(movement.totalSteps) steps")
                        .font(.headline)
                    Text("Moved in \(movement.activeHours) of \(movement.awakeHoursElapsed) hours")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if movement.longestSedentaryStreakHours > 0 {
                        Text("Longest still stretch \(movement.longestSedentaryStreakHours)h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HourStrip(steps: model.todayHourlySteps, awakeHours: profileStore.profile.awakeHours)
                        .frame(height: 22)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Movement")
    }
}
