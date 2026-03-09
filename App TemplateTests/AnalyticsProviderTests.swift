import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
final class AnalyticsProviderTests: XCTestCase {
    private final class LoggerSpy: Logging {
        var debugMessages: [String] = []
        var infoMessages: [String] = []
        var warningMessages: [String] = []
        var errorMessages: [String] = []

        func debug(_ message: String, category: String) {
            debugMessages.append("[\(category)] \(message)")
        }

        func info(_ message: String, category: String) {
            infoMessages.append("[\(category)] \(message)")
        }

        func warning(_ message: String, category: String) {
            warningMessages.append("[\(category)] \(message)")
        }

        func error(_ message: String, category: String) {
            errorMessages.append("[\(category)] \(message)")
        }
    }

    func testResolveNormalizesCaseAndWhitespace() {
        XCTAssertEqual(AnalyticsProvider.resolve("  ConSoLe "), .console)
        XCTAssertEqual(AnalyticsProvider.resolve(" FIREBASE"), .firebase)
        XCTAssertEqual(AnalyticsProvider.resolve("unknown"), .noop)
    }

    func testFactoryReturnsConsoleTracker() {
        let logger = LoggerSpy()
        let tracker = AnalyticsTrackerFactory.make(provider: .console, logger: logger)

        XCTAssertTrue(tracker is ConsoleAnalyticsTracker)
        XCTAssertTrue(logger.infoMessages.contains(where: { $0.contains("Analytics provider: console") }))
    }

    func testFactoryReturnsNoOpForUnknownStringProvider() {
        let logger = LoggerSpy()
        let tracker = AnalyticsTrackerFactory.make(provider: " definitely-not-valid ", logger: logger)

        XCTAssertTrue(tracker is NoOpAnalyticsTracker)
        XCTAssertTrue(logger.infoMessages.contains(where: { $0.contains("Analytics provider: noop") }))
    }

    func testFirebaseTrackerSanitizesEventNameAndPropertiesInLogs() {
        let logger = LoggerSpy()
        let tracker = FirebaseAnalyticsTracker(logger: logger)

        tracker.track(event: AnalyticsEvent(name: "123 purchase-complete!", properties: ["user-id": "42"]))

        XCTAssertTrue(logger.debugMessages.contains(where: { $0.contains("event=e_123_purchase_complete") }))
        XCTAssertTrue(logger.debugMessages.contains(where: { $0.contains("user_id") }))

        #if canImport(FirebaseAnalytics)
        XCTAssertTrue(logger.warningMessages.isEmpty)
        #else
        XCTAssertEqual(logger.warningMessages.count, 1)
        #endif
    }

    func testFirebaseTrackerLogsUnavailableWarningOnlyOnce() {
        let logger = LoggerSpy()
        let tracker = FirebaseAnalyticsTracker(logger: logger)

        tracker.track(event: AnalyticsEvent(name: "Event One"))
        tracker.track(event: AnalyticsEvent(name: "Event Two"))

        #if canImport(FirebaseAnalytics)
        XCTAssertTrue(logger.warningMessages.isEmpty)
        #else
        XCTAssertEqual(logger.warningMessages.count, 1)
        #endif
    }
}
#endif
