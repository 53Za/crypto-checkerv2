import SwiftUI
import KineticCore

struct ProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    private var maxHeartRate: Binding<Double> {
        Binding(
            get: { profileStore.profile.maxHeartRate },
            set: { profileStore.profile.maxHeartRateOverride = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    Stepper("Age: \(profileStore.profile.age)", value: $profileStore.profile.age, in: 13...100)
                    Stepper("Max heart rate: \(Int(profileStore.profile.maxHeartRate)) bpm", value: maxHeartRate, in: 120...230)
                    if profileStore.profile.maxHeartRateOverride != nil {
                        Button("Estimate max heart rate from age") { profileStore.profile.maxHeartRateOverride = nil }
                    }
                }
                Section("Goals") {
                    Stepper("Daily steps: \(profileStore.profile.dailyStepGoal)",
                            value: $profileStore.profile.dailyStepGoal, in: 2_000...30_000, step: 500)
                    Stepper(String(format: "Base sleep need: %.2fh", profileStore.profile.baseSleepNeedHours),
                            value: $profileStore.profile.baseSleepNeedHours, in: 5...11, step: 0.25)
                }
                Section {
                    Stepper("Wake up: \(profileStore.profile.wakeHour):00", value: $profileStore.profile.wakeHour, in: 0...23)
                    Stepper("Bedtime: \(profileStore.profile.bedHour):00", value: $profileStore.profile.bedHour, in: 0...23)
                } header: {
                    Text("Day")
                } footer: {
                    Text("Movement score and move-break nudges only count your awake hours.")
                }
                Section("How Kinetic scores you") {
                    Text("**Charge** compares last night's HRV, resting heart rate and sleep with your own 28-day baseline.")
                    Text("**Load** weights every minute by heart-rate zone. It sets a target range from your Charge.")
                    Text("**Movement** rewards moving every hour, not just one big workout.")
                }
                .font(.footnote)
            }
            .navigationTitle("Profile")
        }
    }
}
