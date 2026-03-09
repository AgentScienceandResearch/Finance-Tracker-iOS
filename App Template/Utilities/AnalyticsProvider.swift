import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsProvider: String {
    case noop
    case console
    case firebase

    static func resolve(_ rawValue: String) -> AnalyticsProvider {
        AnalyticsProvider(
            rawValue: rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        ) ?? .noop
    }
}

enum AnalyticsTrackerFactory {
    static func make(provider: String, logger: Logging) -> AnalyticsTracking {
        make(provider: AnalyticsProvider.resolve(provider), logger: logger)
    }

    static func make(provider: AnalyticsProvider, logger: Logging) -> AnalyticsTracking {
        switch provider {
        case .noop:
            logger.info("Analytics provider: noop", category: "analytics")
            return NoOpAnalyticsTracker.shared
        case .console:
            logger.info("Analytics provider: console", category: "analytics")
            return ConsoleAnalyticsTracker(logger: logger)
        case .firebase:
            logger.info("Analytics provider: firebase", category: "analytics")
            return FirebaseAnalyticsTracker(logger: logger)
        }
    }
}

final class ConsoleAnalyticsTracker: AnalyticsTracking {
    private let logger: Logging

    init(logger: Logging) {
        self.logger = logger
    }

    func track(event: AnalyticsEvent) {
        if event.properties.isEmpty {
            logger.info("event=\(event.name)", category: "analytics")
        } else {
            logger.info("event=\(event.name) properties=\(event.properties)", category: "analytics")
        }
    }
}

final class FirebaseAnalyticsTracker: AnalyticsTracking {
    private let logger: Logging
    private var didLogUnavailableMessage = false

    init(logger: Logging) {
        self.logger = logger
    }

    func track(event: AnalyticsEvent) {
        let eventName = sanitizeName(event.name)
        let parameters = sanitizeProperties(event.properties)

        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(eventName, parameters: parameters)
        #else
        if !didLogUnavailableMessage {
            logger.warning("FirebaseAnalytics not linked; analytics events are not sent.", category: "analytics")
            didLogUnavailableMessage = true
        }
        #endif

        logger.debug("event=\(eventName) properties=\(parameters)", category: "analytics")
    }

    private func sanitizeProperties(_ properties: [String: String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: properties.map { key, value in
            (sanitizeName(key), value)
        })
    }

    private func sanitizeName(_ raw: String) -> String {
        let lowercased = raw.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        let transformed = String(lowercased.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })

        let compact = transformed
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        let prefixed: String
        if compact.isEmpty {
            prefixed = "event"
        } else if let first = compact.first, !first.isLetter {
            prefixed = "e_\(compact)"
        } else {
            prefixed = compact
        }

        return String(prefixed.prefix(40))
    }
}
