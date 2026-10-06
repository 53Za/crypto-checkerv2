import SwiftUI
import KineticCore

enum Theme {
    static let load = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let movement = Color(red: 1.0, green: 0.58, blue: 0.15)
    static let sleep = Color(red: 0.62, green: 0.48, blue: 1.0)

    static func charge(_ level: ChargeLevel) -> Color {
        switch level {
        case .high: return Color(red: 0.2, green: 0.85, blue: 0.5)
        case .moderate: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .low: return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    static func zone(_ zone: HeartRateZone) -> Color {
        switch zone {
        case .rest: return .gray
        case .zone1: return .teal
        case .zone2: return .green
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
}

/// A circular score gauge, with an optional highlighted target band (used for Load).
struct ScoreRing: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let title: String
    var target: LoadTarget?
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            if let target {
                Circle()
                    .trim(from: target.lower / maxValue, to: target.upper / maxValue)
                    .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: lineWidth / 2.5))
                    .rotationEffect(.degrees(-90))
                    .padding(-lineWidth * 0.9)
            }
            Circle()
                .trim(from: 0, to: min(value / maxValue, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: value)
            VStack(spacing: 0) {
                Text("\(Int(value.rounded()))")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(Int(value.rounded()))")
    }
}

/// One bar per awake hour: bright when you hit the step threshold, dim when you didn't.
struct HourStrip: View {
    let steps: [Int]
    let awakeHours: [Int]
    var threshold = MovementCalculator().activeHourStepThreshold

    var body: some View {
        let currentHour = Calendar.current.component(.hour, from: Date())
        HStack(spacing: 1.5) {
            ForEach(awakeHours, id: \.self) { hour in
                let count = steps.indices.contains(hour) ? steps[hour] : 0
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(count: count, isFuture: hour > currentHour))
            }
        }
        .accessibilityLabel("Hourly movement")
    }

    private func color(count: Int, isFuture: Bool) -> Color {
        if isFuture { return .gray.opacity(0.15) }
        return count >= threshold ? Theme.movement : Theme.movement.opacity(0.2)
    }
}
