import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#elseif canImport(FinanceTrackerAI)
@testable import FinanceTrackerAI
#endif

#if canImport(App_Template) || canImport(TemplateApp) || canImport(FinanceTrackerAI)
final class AppConfigTests: XCTestCase {
    private struct StubEnvironment: EnvironmentValueProviding {
        let environment: [String: String]
    }

    private struct StubInfoDictionary: InfoDictionaryValueProviding {
        let values: [String: String]

        func infoValue(for key: String) -> String? {
            values[key]
        }
    }

    func testLoadPrefersProcessEnvironmentValues() {
        let config = AppConfig.load(
            bundle: StubInfoDictionary(
                values: [
                    "APP_ENV": "Release",
                    "API_URL": "https://plist.example.com",
                    "GITHUB_TOKEN": "plist-token",
                    "ANALYTICS_PROVIDER": "noop"
                ]
            ),
            processInfo: StubEnvironment(
                environment: [
                    "APP_ENV": "Staging",
                    "API_URL": "https://runtime.example.com",
                    "GITHUB_TOKEN": "runtime-token",
                    "ANALYTICS_PROVIDER": "ConSole"
                ]
            )
        )

        XCTAssertEqual(config.environment, "Staging")
        XCTAssertEqual(config.apiURL.absoluteString, "https://runtime.example.com")
        XCTAssertEqual(config.gitHubToken, "runtime-token")
        XCTAssertEqual(config.analyticsProvider, .console)
    }

    func testLoadFallsBackToInfoDictionaryValues() {
        let config = AppConfig.load(
            bundle: StubInfoDictionary(
                values: [
                    "APP_ENV": "Release",
                    "API_URL": "https://plist.example.com",
                    "GITHUB_TOKEN": "plist-token",
                    "ANALYTICS_PROVIDER": "firebase"
                ]
            ),
            processInfo: StubEnvironment(environment: [:])
        )

        XCTAssertEqual(config.environment, "Release")
        XCTAssertEqual(config.apiURL.absoluteString, "https://plist.example.com")
        XCTAssertEqual(config.gitHubToken, "plist-token")
        XCTAssertEqual(config.analyticsProvider, .firebase)
    }

    func testLoadUsesSafeDefaultsWhenValuesMissing() {
        let config = AppConfig.load(
            bundle: StubInfoDictionary(values: [:]),
            processInfo: StubEnvironment(environment: [:])
        )

        XCTAssertEqual(config.environment, "Debug")
        XCTAssertEqual(config.apiURL.absoluteString, "http://localhost:8000")
        XCTAssertEqual(config.gitHubToken, "")
        XCTAssertEqual(config.analyticsProvider, .noop)
    }

    func testLoadUsesDefaultURLWhenConfiguredURLIsInvalid() {
        let config = AppConfig.load(
            bundle: StubInfoDictionary(values: [:]),
            processInfo: StubEnvironment(environment: ["API_URL": "not-a-valid-url"])
        )

        XCTAssertEqual(config.apiURL.absoluteString, "http://localhost:8000")
    }

    @MainActor
    func testLanguageSelectionPersistsAcrossControllerRelaunch() {
        let suiteName = "AppLanguageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = AppLanguageController(defaults: defaults)
        XCTAssertEqual(firstLaunch.selectedIdentifier, AppLanguage.defaultIdentifier)
        XCTAssertEqual(firstLaunch.locale.identifier, "en-US")
        XCTAssertTrue(defaults.bool(forKey: AppLanguage.englishDefaultMigrationKey))

        firstLaunch.select("fr-FR")
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "fr-FR")

        let relaunched = AppLanguageController(defaults: defaults)
        XCTAssertEqual(relaunched.selectedIdentifier, "fr-FR")
        XCTAssertEqual(relaunched.locale.identifier, "fr-FR")

        relaunched.select("ar-SA")
        XCTAssertEqual(relaunched.layoutDirection, .rightToLeft)

        relaunched.select(AppLanguage.systemDefaultIdentifier)
        XCTAssertEqual(
            defaults.string(forKey: AppLanguage.storageKey),
            AppLanguage.systemDefaultIdentifier
        )
        XCTAssertEqual(relaunched.selectedIdentifier, AppLanguage.systemDefaultIdentifier)
        XCTAssertFalse(relaunched.selectedIdentifier.isEmpty)
    }

    @MainActor
    func testLegacyLanguageIsResetToEnglishOnceAndSystemChoiceRemainsExplicit() {
        let suiteName = "AppLanguageLegacyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("he", forKey: AppLanguage.storageKey)
        let controller = AppLanguageController(defaults: defaults)
        XCTAssertEqual(controller.selectedIdentifier, "en-US")
        XCTAssertEqual(controller.layoutDirection, .leftToRight)
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "en-US")

        controller.select("")

        XCTAssertEqual(controller.selectedIdentifier, AppLanguage.systemDefaultIdentifier)
        XCTAssertEqual(
            defaults.string(forKey: AppLanguage.storageKey),
            AppLanguage.systemDefaultIdentifier
        )
        XCTAssertEqual(
            controller.locale.identifier.replacingOccurrences(of: "_", with: "-"),
            Locale.preferredLanguages.first?.replacingOccurrences(of: "_", with: "-")
        )
    }

    func testLanguageListMatchesCompiledLocalizationCount() {
        XCTAssertEqual(AppLanguage.supportedIdentifiers.count, 36)
        XCTAssertEqual(Set(AppLanguage.supportedIdentifiers).count, 36)
        XCTAssertTrue(AppLanguage.supportedIdentifiers.contains("hi"))
        XCTAssertTrue(AppLanguage.supportedIdentifiers.contains("ar-SA"))
        XCTAssertTrue(AppLanguage.supportedIdentifiers.contains("he"))
        XCTAssertTrue(AppLanguage.supportedIdentifiers.contains("nb"))
        XCTAssertTrue(AppLanguage.supportedIdentifiers.allSatisfy {
            !AppLanguage.nativeDisplayName(for: $0).isEmpty
        })
    }
}
#endif
