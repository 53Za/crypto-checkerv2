import SwiftUI

@main
struct KineticApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var reportModel = ReportModel(trendDays: 14)

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Today", systemImage: "circle.circle") }
                TrendsView()
                    .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            .environmentObject(profileStore)
            .environmentObject(reportModel)
            .preferredColorScheme(.dark)
        }
    }
}
