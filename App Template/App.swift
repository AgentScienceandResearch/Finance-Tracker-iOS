import SwiftUI

@main
struct TemplateApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(environment.financeManager)
                .environmentObject(environment.financeAIManager)
                .environment(\.analyticsTracker, environment.analytics)
                .dismissKeyboardOnTapOutsideTextInput()
        }
    }
}
