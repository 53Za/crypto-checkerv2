import Foundation
import UserNotifications
import WatchKit
import KineticCore

/// Kinetic's "move break" nudges: a background refresh near the end of each awake hour
/// checks that hour's steps and taps your wrist if you've barely moved.
enum MovementNudger {
    static let refreshIdentifier = "kinetic.movement-check"
    private static let minuteToCheck = 50

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Schedules the next background check for minute 50 of the coming hour.
    static func scheduleNext(from date: Date = Date()) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = minuteToCheck
        var next = calendar.date(from: components) ?? date.addingTimeInterval(3600)
        if next <= date { next = calendar.date(byAdding: .hour, value: 1, to: next) ?? date.addingTimeInterval(3600) }

        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: next,
            userInfo: refreshIdentifier as NSString
        ) { _ in }
    }

    /// Called from the app's background refresh task.
    static func performCheck(profile: UserProfile) async {
        defer { scheduleNext() }
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        guard profile.awakeHours.contains(hour) else { return }

        let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        let dayStart = calendar.startOfDay(for: now)
        let steps = (try? await HealthDataProvider.shared.hourlySteps(from: dayStart, to: now)) ?? []
        let thisHour = steps.indices.contains(hour) ? steps[hour] : 0
        let threshold = MovementCalculator().activeHourStepThreshold
        guard thisHour < threshold, now.timeIntervalSince(hourStart) >= 40 * 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to move"
        content.body = "Only \(thisHour) steps this hour. A \(max(threshold - thisHour, 50))-step walk keeps your Movement score up."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "kinetic.nudge.\(hour)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
