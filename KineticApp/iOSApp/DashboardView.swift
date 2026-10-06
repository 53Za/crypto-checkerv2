import SwiftUI
import KineticCore

struct DashboardView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var model: ReportModel

    var body: some View {
        NavigationStack {
            ScrollView {
                if let report = model.today {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ScoreRing(value: report.charge.score, maxValue: 100,
                                      color: Theme.charge(report.charge.level), title: "Charge", lineWidth: 12)
                            ScoreRing(value: report.load, maxValue: 100, color: Theme.load,
                                      title: "Load", target: report.loadTarget, lineWidth: 12)
                            ScoreRing(value: report.movement.score, maxValue: 100,
                                      color: Theme.movement, title: "Movement", lineWidth: 12)
                        }
                        .frame(height: 110)
                        .padding(.vertical, 8)

                        Card(title: "Coach") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(report.insights, id: \.self) { line in
                                    Label(line, systemImage: "sparkle").font(.subheadline)
                                }
                            }
                        }

                        Card(title: "Charge breakdown") {
                            VStack(spacing: 6) {
                                ComponentRow(name: "Heart-rate variability", value: report.charge.hrvComponent)
                                ComponentRow(name: "Resting heart rate", value: report.charge.restingHeartRateComponent)
                                ComponentRow(name: "Sleep", value: report.charge.sleepComponent)
                            }
                        }

                        if let sleep = report.sleep {
                            Card(title: "Sleep") {
                                HStack {
                                    Stat(value: String(format: "%.1fh", sleep.actualHours), label: "Slept")
                                    Stat(value: String(format: "%.1fh", sleep.needHours), label: "Needed")
                                    Stat(value: "\(Int(sleep.performance * 100))%", label: "Performance")
                                    if let efficiency = sleep.efficiency {
                                        Stat(value: "\(Int(efficiency * 100))%", label: "Efficiency")
                                    }
                                }
                                .foregroundStyle(Theme.sleep)
                            }
                        }

                        Card(title: "Movement") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Stat(value: "\(report.movement.totalSteps)", label: "Steps")
                                    Stat(value: "\(report.movement.activeHours)/\(report.movement.awakeHoursElapsed)", label: "Active hours")
                                    Stat(value: "\(report.movement.longestSedentaryStreakHours)h", label: "Longest still")
                                }
                                HourStrip(steps: model.todayHourlySteps, awakeHours: profileStore.profile.awakeHours)
                                    .frame(height: 28)
                            }
                        }

                        Card(title: "Heart-rate zones today") {
                            ZoneBars(minutes: report.minutesInZones)
                        }
                    }
                    .padding()
                } else if let error = model.errorMessage {
                    ContentUnavailableView("Can't read Health data", systemImage: "heart.slash", description: Text(error))
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .navigationTitle("Today")
            .refreshable { await model.refresh(profile: profileStore.profile) }
            // Re-runs when settings change; the short delay coalesces rapid stepper taps.
            .task(id: profileStore.profile) {
                if model.today != nil {
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { return }
                }
                await model.refresh(profile: profileStore.profile)
            }
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ComponentRow: View {
    let name: String
    let value: Double?

    var body: some View {
        HStack {
            Text(name).font(.subheadline)
            Spacer()
            if let value {
                ProgressView(value: value, total: 100)
                    .frame(width: 100)
                    .tint(Theme.charge(ChargeLevel(score: value)))
                Text("\(Int(value))").monospacedDigit().frame(width: 30, alignment: .trailing)
            } else {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ZoneBars: View {
    let minutes: [HeartRateZone: Double]

    var body: some View {
        let maxMinutes = max(minutes.values.max() ?? 1, 1)
        VStack(spacing: 6) {
            ForEach(HeartRateZone.allCases.reversed(), id: \.self) { zone in
                let value = minutes[zone] ?? 0
                HStack {
                    Text(zone.name).font(.caption).frame(width: 74, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(Theme.zone(zone))
                            .frame(width: max(proxy.size.width * value / maxMinutes, 2))
                    }
                    .frame(height: 8)
                    Text("\(Int(value.rounded()))m").font(.caption).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        }
    }
}
