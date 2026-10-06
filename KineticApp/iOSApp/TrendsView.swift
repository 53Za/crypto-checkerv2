import SwiftUI
import Charts
import KineticCore

struct TrendsView: View {
    @EnvironmentObject private var model: ReportModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Charge vs Load") {
                        Chart(model.trend, id: \.date) { report in
                            LineMark(x: .value("Day", report.date, unit: .day), y: .value("Score", report.charge.score))
                                .foregroundStyle(by: .value("Metric", "Charge"))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Day", report.date, unit: .day), y: .value("Score", report.load))
                                .foregroundStyle(by: .value("Metric", "Load"))
                                .interpolationMethod(.catmullRom)
                        }
                        .chartForegroundStyleScale(["Charge": Theme.charge(.high), "Load": Theme.load])
                        .chartYScale(domain: 0...100)
                        .frame(height: 200)
                    }

                    Card(title: "Movement") {
                        Chart(model.trend, id: \.date) { report in
                            BarMark(x: .value("Day", report.date, unit: .day), y: .value("Movement", report.movement.score))
                                .foregroundStyle(Theme.movement)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 160)
                    }

                    Card(title: "Sleep vs need") {
                        Chart(model.trend.filter { $0.sleep != nil }, id: \.date) { report in
                            BarMark(x: .value("Day", report.date, unit: .day), y: .value("Hours", report.sleep!.actualHours))
                                .foregroundStyle(Theme.sleep)
                            PointMark(x: .value("Day", report.date, unit: .day), y: .value("Need", report.sleep!.needHours))
                                .symbol(.diamond)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(height: 160)
                    }

                    Text("Charge high and Load low means you have room to push. Load above Charge for several days in a row is a sign to back off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
    }
}
