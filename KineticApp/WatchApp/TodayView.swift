import SwiftUI
import KineticCore

/// Glanceable home screen: Charge and Load rings, with today's Load target.
struct TodayView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var model: ReportModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let report = model.today {
                    HStack(spacing: 12) {
                        ScoreRing(value: report.charge.score, maxValue: 100,
                                  color: Theme.charge(report.charge.level), title: "Charge")
                        ScoreRing(value: report.load, maxValue: 100, color: Theme.load,
                                  title: "Load", target: report.loadTarget)
                    }
                    .frame(height: 74)
                    .padding(.top, 6)

                    Text("Target Load \(Int(report.loadTarget.lower))–\(Int(report.loadTarget.upper))")
                        .font(.caption2)
                        .foregroundStyle(Theme.load)

                    if let line = report.insights.first(where: { !$0.hasPrefix("Still learning") }) ?? report.insights.first {
                        Text(line)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let sleep = report.sleep {
                        Label(String(format: "%.1fh / %.1fh sleep", sleep.actualHours, sleep.needHours), systemImage: "bed.double.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.sleep)
                    }
                } else if let error = model.errorMessage {
                    Text(error).font(.footnote).multilineTextAlignment(.center)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Kinetic")
        .task(id: profileStore.profile) { await model.refresh(profile: profileStore.profile) }
    }
}
