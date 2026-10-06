import SwiftUI
import KineticCore

struct SettingsView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        Form {
            Stepper("Age \(profileStore.profile.age)", value: $profileStore.profile.age, in: 13...100)
            Stepper("Steps \(profileStore.profile.dailyStepGoal)", value: $profileStore.profile.dailyStepGoal, in: 2_000...30_000, step: 500)
            Stepper(String(format: "Sleep %.1fh", profileStore.profile.baseSleepNeedHours),
                    value: $profileStore.profile.baseSleepNeedHours, in: 5...11, step: 0.25)
            Stepper("Wake \(profileStore.profile.wakeHour):00", value: $profileStore.profile.wakeHour, in: 0...23)
            Stepper("Bed \(profileStore.profile.bedHour):00", value: $profileStore.profile.bedHour, in: 0...23)
        }
        .navigationTitle("Settings")
    }
}
