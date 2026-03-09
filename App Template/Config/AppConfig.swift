import Foundation

protocol EnvironmentValueProviding {
    var environment: [String: String] { get }
}

extension ProcessInfo: EnvironmentValueProviding {}

protocol InfoDictionaryValueProviding {
    func infoValue(for key: String) -> String?
}

extension Bundle: InfoDictionaryValueProviding {
    func infoValue(for key: String) -> String? {
        object(forInfoDictionaryKey: key) as? String
    }
}

struct AppConfig {
    let environment: String
    let apiURL: URL
    let gitHubToken: String
    let analyticsProvider: AnalyticsProvider

    static let shared = AppConfig.load()

    static func load(
        bundle: InfoDictionaryValueProviding = Bundle.main,
        processInfo: EnvironmentValueProviding = ProcessInfo.processInfo
    ) -> AppConfig {
        let env = value(
            key: "APP_ENV",
            bundle: bundle,
            processInfo: processInfo,
            fallback: "Debug"
        )

        let apiURLString = value(
            key: "API_URL",
            bundle: bundle,
            processInfo: processInfo,
            fallback: "http://localhost:8000"
        )

        let token = value(
            key: "GITHUB_TOKEN",
            bundle: bundle,
            processInfo: processInfo,
            fallback: ""
        )

        let analyticsProvider = value(
            key: "ANALYTICS_PROVIDER",
            bundle: bundle,
            processInfo: processInfo,
            fallback: "noop"
        )

        let resolvedAPIURL: URL
        if let candidate = URL(string: apiURLString),
           let scheme = candidate.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           candidate.host != nil {
            resolvedAPIURL = candidate
        } else {
            resolvedAPIURL = URL(string: "http://localhost:8000")!
        }

        return AppConfig(
            environment: env,
            apiURL: resolvedAPIURL,
            gitHubToken: token,
            analyticsProvider: AnalyticsProvider.resolve(analyticsProvider)
        )
    }

    private static func value(
        key: String,
        bundle: InfoDictionaryValueProviding,
        processInfo: EnvironmentValueProviding,
        fallback: String
    ) -> String {
        if let runtime = processInfo.environment[key], !runtime.isEmpty {
            return runtime
        }

        if let plistValue = bundle.infoValue(for: key),
           !plistValue.isEmpty,
           plistValue != "$(\(key))" {
            return plistValue
        }

        return fallback
    }
}
