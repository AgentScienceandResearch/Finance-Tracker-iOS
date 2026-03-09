import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let config: AppConfig
    let logger: Logging
    let analytics: AnalyticsTracking

    // Template services kept for future extension where relevant.
    let databaseManager: DatabaseManager
    let authManager: AuthenticationManager
    let subscriptionManager: SubscriptionManager
    let apiService: APIService
    let gitHubService: GitHubService

    // Finance app runtime dependencies.
    let openAIService: OpenAIService
    let financeManager: FinanceManager
    let financeAIManager: FinanceAIManager

    private var cancellables = Set<AnyCancellable>()

    init(
        databaseManager: DatabaseManager,
        subscriptionManager: SubscriptionManager,
        apiService: APIService,
        gitHubService: GitHubService,
        openAIService: OpenAIService,
        financeManager: FinanceManager,
        config: AppConfig,
        logger: Logging,
        analytics: AnalyticsTracking
    ) {
        self.config = config
        self.logger = logger
        self.analytics = analytics

        self.databaseManager = databaseManager
        self.subscriptionManager = subscriptionManager
        self.apiService = apiService
        self.gitHubService = gitHubService
        self.openAIService = openAIService
        self.financeManager = financeManager

        self.authManager = AuthenticationManager(
            userRepository: UserRepository(userStore: databaseManager),
            logger: logger,
            analytics: analytics
        )

        self.financeAIManager = FinanceAIManager(
            service: openAIService,
            logger: logger,
            analytics: analytics
        )

        bindManagerChanges()
    }

    convenience init() {
        let config = AppConfig.shared
        let logger = AppLogger.shared
        let analytics = AnalyticsTrackerFactory.make(provider: config.analyticsProvider, logger: logger)
        let openAIService = OpenAIService(config: config, logger: logger)

        self.init(
            databaseManager: .shared,
            subscriptionManager: .shared,
            apiService: .shared,
            gitHubService: .shared,
            openAIService: openAIService,
            financeManager: .shared,
            config: config,
            logger: logger,
            analytics: analytics
        )
    }

    private func bindManagerChanges() {
        financeManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
