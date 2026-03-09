import SwiftUI
import StoreKit

@MainActor
class SubscriptionManager: NSObject, ObservableObject, SubscriptionManaging {
    static let shared = SubscriptionManager(
        repository: StoreKitSubscriptionRepository(),
        logger: AppLogger.shared,
        analytics: NoOpAnalyticsTracker.shared
    )
    
    // MARK: - Product IDs (update with your app's IDs)
    static let weeklyProductID = "your_app.subscription.weekly"
    static let monthlyProductID = "your_app.subscription.monthly"
    static let yearlyProductID = "your_app.subscription.yearly"
    
    static let subscriptionProductIDs = [weeklyProductID, monthlyProductID, yearlyProductID]
    static let allProductIDs = subscriptionProductIDs
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var isSubscribed = false
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var productsLoaded = false
    
    // MARK: - UserDefaults Keys
    private static let subscriptionStatusKey = "cachedSubscriptionStatus"
    private static let subscriptionExpiryKey = "cachedSubscriptionExpiry"
    
    var sortedProducts: [Product] {
        products.filter { Self.subscriptionProductIDs.contains($0.id) }
            .sorted { p1, p2 in
                let order = [Self.weeklyProductID, Self.monthlyProductID, Self.yearlyProductID]
                let i1 = order.firstIndex(of: p1.id) ?? 0
                let i2 = order.firstIndex(of: p2.id) ?? 0
                return i1 < i2
            }
    }

    var plans: [SubscriptionPlan] {
        sortedProducts.map(Self.makePlan(for:))
    }
    
    private var updateListenerTask: Task<Void, Never>?
    private let repository: SubscriptionRepositorying
    private let logger: Logging
    private let analytics: AnalyticsTracking
    
    private init(
        repository: SubscriptionRepositorying,
        logger: Logging,
        analytics: AnalyticsTracking,
        autoStart: Bool = true
    ) {
        self.repository = repository
        self.logger = logger
        self.analytics = analytics
        super.init()
        loadCachedSubscriptionStatus()
        
        guard autoStart else { return }

        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts(forceReload: Bool = false) async {
        if productsLoaded && !forceReload {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await repository.loadProducts(productIDs: Self.allProductIDs)
            productsLoaded = true
            loadError = nil
            logger.info("Loaded subscription products: \(products.count)", category: "subscription")
        } catch {
            loadError = "Failed to load products: \(error.localizedDescription)"
            logger.error("Failed loading products: \(error.localizedDescription)", category: "subscription")
        }
    }
    
    // MARK: - Purchase Product
    func purchase(planID: String) async -> Bool {
        guard let product = sortedProducts.first(where: { $0.id == planID }) else {
            loadError = "Selected subscription plan is unavailable."
            return false
        }

        return await purchase(product)
    }

    private func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await repository.purchase(product)
            
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await updateSubscriptionStatus()
                analytics.track(event: AnalyticsEvent(name: "subscription_purchase_success", properties: ["product_id": product.id]))
                logger.info("Subscription purchase success: \(product.id)", category: "subscription")
                return true
                
            case .success(.unverified(_, _)):
                loadError = "Transaction verification failed"
                logger.warning("Unverified transaction for product: \(product.id)", category: "subscription")
                return false
                
            case .pending:
                logger.info("Subscription purchase pending: \(product.id)", category: "subscription")
                return false
                
            case .userCancelled:
                logger.info("Subscription purchase cancelled by user: \(product.id)", category: "subscription")
                return false
                
            @unknown default:
                return false
            }
        } catch {
            loadError = "Purchase failed: \(error.localizedDescription)"
            logger.error("Subscription purchase failed: \(error.localizedDescription)", category: "subscription")
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.syncPurchases()
            await updateSubscriptionStatus()
            analytics.track(event: AnalyticsEvent(name: "subscription_restore_complete"))
            logger.info("Restore purchases completed", category: "subscription")
        } catch {
            loadError = "Restore failed: \(error.localizedDescription)"
            logger.error("Restore purchases failed: \(error.localizedDescription)", category: "subscription")
        }
    }
    
    // MARK: - Update Subscription Status
    private func updateSubscriptionStatus() async {
        let entitlements = await repository.currentEntitledProductIDs()
        let subscribed = entitlements.contains { Self.subscriptionProductIDs.contains($0) }
        
        self.isSubscribed = subscribed
        UserDefaults.standard.set(subscribed, forKey: Self.subscriptionStatusKey)
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Never> {
        let updates = repository.transactionUpdates()
        return Task(priority: .background) {
            for await result in updates {
                guard case .verified(let transaction) = result else { continue }
                
                await updateSubscriptionStatus()
                await transaction.finish()
            }
        }
    }
    
    // MARK: - Cached Status
    private func loadCachedSubscriptionStatus() {
        let cachedStatus = UserDefaults.standard.bool(forKey: Self.subscriptionStatusKey)
        if cachedStatus {
            if let expiryDate = UserDefaults.standard.object(forKey: Self.subscriptionExpiryKey) as? Date,
               expiryDate > Date() {
                isSubscribed = true
            }
        }
    }

    private static func makePlan(for product: Product) -> SubscriptionPlan {
        SubscriptionPlan(
            id: product.id,
            title: product.displayName,
            billingPeriod: billingPeriod(for: product),
            displayPrice: product.displayPrice,
            pricePerMonth: pricePerMonth(for: product)
        )
    }

    private static func billingPeriod(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return "Unknown"
        }

        switch period.unit {
        case .day:
            return "\(period.value) day\(period.value == 1 ? "" : "s")"
        case .week:
            return "\(period.value) week\(period.value == 1 ? "" : "s")"
        case .month:
            return "\(period.value) month\(period.value == 1 ? "" : "s")"
        case .year:
            return "\(period.value) year\(period.value == 1 ? "" : "s")"
        @unknown default:
            return "Unknown"
        }
    }

    private static func pricePerMonth(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        let months: Decimal
        switch period.unit {
        case .day:
            months = Decimal(period.value) / 30
        case .week:
            months = Decimal(period.value) / 4.33
        case .month:
            months = Decimal(period.value)
        case .year:
            months = Decimal(period.value) * 12
        @unknown default:
            months = 1
        }

        guard months > 0 else { return nil }
        let perMonth = product.price / months
        return "~\(perMonth.description)/mo"
    }

    static func makeForTesting(
        repository: SubscriptionRepositorying,
        logger: Logging = AppLogger.shared,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker.shared
    ) -> SubscriptionManager {
        SubscriptionManager(
            repository: repository,
            logger: logger,
            analytics: analytics,
            autoStart: false
        )
    }
}
