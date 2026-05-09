import SwiftUI
import UIKit

// AppDelegate runs before any SwiftUI state is initialized,
// guaranteeing Firebase is configured before FinanceManager/DatabaseManager wake up.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configure()
        return true
    }
}

@main
struct TemplateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
