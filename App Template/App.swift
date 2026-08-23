import SwiftUI
import UIKit

enum AppLanguage {
    static let storageKey = "app.displayLanguage"
    static let systemDefaultIdentifier = ""

    /// These identifiers mirror the 36 Localizable.strings folders emitted by
    /// the string catalog. Norwegian is emitted by Xcode as `nb.lproj`.
    static let supportedIdentifiers = [
        "ar-SA", "bn-BD", "de-DE", "en-AU", "en-CA", "en-GB", "en-US",
        "es-MX", "fr-CA", "fr-FR", "gu-IN", "he", "hi", "hr", "id", "it",
        "ja", "kn-IN", "ko", "ml-IN", "mr-IN", "ms", "nb", "nl-NL",
        "or-IN", "pa-IN", "pt-BR", "ta-IN", "te-IN", "th", "tr", "uk",
        "ur-PK", "vi", "zh-Hans", "zh-Hant"
    ]

    static func persistedIdentifier(defaults: UserDefaults = .standard) -> String {
        sanitized(defaults.string(forKey: storageKey) ?? systemDefaultIdentifier)
    }

    static func persist(_ identifier: String, defaults: UserDefaults = .standard) {
        let identifier = sanitized(identifier)
        if identifier == systemDefaultIdentifier {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(identifier, forKey: storageKey)
        }
    }

    static func locale(for identifier: String) -> Locale {
        let identifier = sanitized(identifier)
        return identifier.isEmpty ? .autoupdatingCurrent : Locale(identifier: identifier)
    }

    static var currentLocale: Locale {
        locale(for: persistedIdentifier())
    }

    static var requestIdentifier: String {
        currentLocale.identifier
    }

    static var responseLanguageName: String {
        let locale = currentLocale
        return locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: localizationBundle, locale: currentLocale)
    }

    static func nativeDisplayName(for identifier: String) -> String {
        guard !identifier.isEmpty else {
            let systemLocale = Locale.autoupdatingCurrent
            let systemName = systemLocale.localizedString(forIdentifier: systemLocale.identifier)
                ?? systemLocale.identifier
            return "System Default — \(systemName)"
        }

        let locale = Locale(identifier: identifier)
        return locale.localizedString(forIdentifier: identifier) ?? identifier
    }

    static func isRightToLeft(_ identifier: String) -> Bool {
        Locale.Language(identifier: locale(for: identifier).identifier).characterDirection == .rightToLeft
    }

    private static func sanitized(_ identifier: String) -> String {
        supportedIdentifiers.contains(identifier) ? identifier : systemDefaultIdentifier
    }

    private static var localizationBundle: Bundle {
        let identifier = persistedIdentifier()
        guard !identifier.isEmpty,
              let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

@MainActor
final class AppLanguageController: ObservableObject {
    static let shared = AppLanguageController()

    @Published private(set) var selectedIdentifier: String
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedIdentifier = AppLanguage.persistedIdentifier(defaults: defaults)
    }

    var locale: Locale {
        AppLanguage.locale(for: selectedIdentifier)
    }

    var layoutDirection: LayoutDirection {
        AppLanguage.isRightToLeft(selectedIdentifier) ? .rightToLeft : .leftToRight
    }

    var selectedDisplayName: String {
        AppLanguage.nativeDisplayName(for: selectedIdentifier)
    }

    func select(_ identifier: String) {
        AppLanguage.persist(identifier, defaults: defaults)
        selectedIdentifier = AppLanguage.persistedIdentifier(defaults: defaults)
    }
}

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
    @StateObject private var languageController = AppLanguageController.shared
    @StateObject private var environment = AppEnvironment()
    @State private var showSplash = true
    @State private var showPaywall = false
    @State private var paywallMode: PaywallMode = .initial

    var body: some Scene {
        WindowGroup {
            ZStack {
                if environment.authManager.isAuthenticated {
                    MainTabView(canPresentAIWelcome: !showSplash && !showPaywall)
                        .environmentObject(environment.financeManager)
                        .environmentObject(environment.financeAIManager)
                        .environmentObject(environment.authManager)
                        .environmentObject(environment.subscriptionManager)
                        .environment(\.analyticsTracker, environment.analytics)
                        .dismissKeyboardOnTapOutsideTextInput()
                        .transition(.opacity)
                } else if !showSplash {
                    AuthenticationView(authManager: environment.authManager)
                        .transition(.opacity)
                }

                if showSplash {
                    SplashView(isShowing: $showSplash)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .animation(.easeInOut(duration: 0.35), value: environment.authManager.isAuthenticated)
            .environmentObject(languageController)
            .environment(\.locale, languageController.locale)
            .environment(\.layoutDirection, languageController.layoutDirection)
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(
                    subscriptionManager: environment.subscriptionManager,
                    mode: paywallMode,
                    onDismiss: paywallMode == .initial ? { showPaywall = false } : nil
                )
            }
            .onChange(of: environment.authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated { evaluatePaywall() }
            }
            .onChange(of: environment.subscriptionManager.isSubscribed) { _, isSubscribed in
                if isSubscribed { showPaywall = false }
            }
            .onChange(of: languageController.selectedIdentifier) { _, _ in
                environment.financeAIManager.refreshLocalizedWelcomeIfIdle()
            }
            .task {
                if environment.authManager.isAuthenticated { evaluatePaywall() }
            }
        }
    }

    // MARK: - Paywall logic

    private func evaluatePaywall() {
        guard !environment.subscriptionManager.isSubscribed else { return }
        guard let userID = environment.authManager.currentUser?.id,
              let mode = PaywallAccessPolicy.modeAtLaunch(userID: userID) else { return }

        paywallMode = mode
        showPaywall = true
    }
}

enum PaywallAccessPolicy {
    static let freePeriodDays = 7

    static func modeAtLaunch(
        userID: String,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) -> PaywallMode? {
        guard let startDate = defaults.object(forKey: startDateKey(userID: userID)) as? Date else {
            // A new free user is not interrupted on launch. Their free period starts
            // only after the first successful AI response.
            return nil
        }
        return isExpired(startDate: startDate, now: now) ? .yearlyHard : nil
    }

    static func modeAfterSuccessfulAIUse(
        userID: String,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) -> PaywallMode? {
        let key = startDateKey(userID: userID)
        if let startDate = defaults.object(forKey: key) as? Date {
            return isExpired(startDate: startDate, now: now) ? .yearlyHard : nil
        }

        defaults.set(now, forKey: key)
        return .initial
    }

    private static func startDateKey(userID: String) -> String {
        "freeTrialStart_\(userID)"
    }

    private static func isExpired(startDate: Date, now: Date) -> Bool {
        now.timeIntervalSince(startDate) >= TimeInterval(freePeriodDays * 24 * 60 * 60)
    }
}

// MARK: - Splash Screen

private struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var displayedText = ""
    @State private var showLogo = false
    @State private var showBadge = false

    private static let green = Color(red: 0.18, green: 0.72, blue: 0.34)
    private let appName = "Finance Tracker"

    var body: some View {
        ZStack {
            Self.green.ignoresSafeArea()

            VStack(spacing: 20) {
                if showLogo {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }

                Text(displayedText)
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(nil, value: displayedText)

                if showBadge {
                    Text("AI")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Self.green)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(.white)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear(perform: runAnimation)
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showLogo = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            typewrite()
        }
    }

    private func typewrite() {
        for (i, char) in appName.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.065) {
                displayedText.append(char)
            }
        }

        let done = Double(appName.count) * 0.065 + 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + done) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showBadge = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + done + 1.1) {
            isShowing = false
        }
    }
}
