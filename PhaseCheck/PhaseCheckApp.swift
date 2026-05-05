
import SwiftUI

@main
struct PhaseCheckApp: App {
    @StateObject private var store = AppDataStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

private struct AppRootView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    var body: some View {
        Group {
            if onboardingCompleted {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
    }
}
