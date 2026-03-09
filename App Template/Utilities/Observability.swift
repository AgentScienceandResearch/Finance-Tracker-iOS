import Foundation
import OSLog
import SwiftUI

protocol Logging {
    func debug(_ message: String, category: String)
    func info(_ message: String, category: String)
    func warning(_ message: String, category: String)
    func error(_ message: String, category: String)
}

protocol AnalyticsTracking {
    func track(event: AnalyticsEvent)
}

struct AnalyticsEvent {
    let name: String
    let properties: [String: String]

    init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

final class AppLogger: Logging {
    static let shared = AppLogger()

    private init() {}

    func debug(_ message: String, category: String) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    func info(_ message: String, category: String) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    func warning(_ message: String, category: String) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    func error(_ message: String, category: String) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    private func logger(for category: String) -> Logger {
        Logger(subsystem: "com.template.iosapptemplate", category: category)
    }
}

final class NoOpAnalyticsTracker: AnalyticsTracking {
    static let shared = NoOpAnalyticsTracker()

    private init() {}

    func track(event: AnalyticsEvent) {
        // Intentionally no-op; replace with Firebase/Mixpanel implementation.
    }
}

private struct AnalyticsTrackerEnvironmentKey: EnvironmentKey {
    static let defaultValue: AnalyticsTracking = NoOpAnalyticsTracker.shared
}

extension EnvironmentValues {
    var analyticsTracker: AnalyticsTracking {
        get { self[AnalyticsTrackerEnvironmentKey.self] }
        set { self[AnalyticsTrackerEnvironmentKey.self] = newValue }
    }
}
