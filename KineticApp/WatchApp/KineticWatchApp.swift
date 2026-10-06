import SwiftUI
import KineticCore

@main
struct KineticWatchApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var reportModel = ReportModel()
    @StateObject private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(reportModel)
                .environmentObject(workoutManager)
                .task {
                    await MovementNudger.requestPermission()
                    MovementNudger.scheduleNext()
                }
        }
        .backgroundTask(.appRefresh(MovementNudger.refreshIdentifier)) {
            let profile = await MainActor.run { profileStore.profile }
            await MovementNudger.performCheck(profile: profile)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        NavigationStack {
            if workoutManager.state == .idle {
                TabView {
                    TodayView()
                    StartSessionView()
                    MovementView()
                    SettingsView()
                }
                .tabViewStyle(.verticalPage)
            } else if workoutManager.state == .ended {
                SessionSummaryView()
            } else {
                LiveSessionView()
            }
        }
    }
}
