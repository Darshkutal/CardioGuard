import SwiftUI
import SwiftData

@main
struct CardioGuardApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, VitalReading.self, SymptomEntry.self])
    }
}

/// Shows onboarding until the profile is completed, then the main tab UI.
struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.first?.completedOnboarding == true {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "heart.text.square") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
