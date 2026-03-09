import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
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
}
#endif
