import Foundation

@MainActor
final class PaywallFlowViewModel: ObservableObject {
    @Published private(set) var plans: [SubscriptionPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var isSubscribed = false
    @Published var selectedPlanID: String?
    @Published var isPurchasing = false
    @Published var statusMessage: String?

    private let subscriptionManager: SubscriptionManaging

    init(subscriptionManager: SubscriptionManaging) {
        self.subscriptionManager = subscriptionManager
        syncFromManager()
    }

    func loadPlans() async {
        isLoading = true
        loadError = nil
        await subscriptionManager.loadProducts(forceReload: false)
        syncFromManager()
        isLoading = false
        if selectedPlanID == nil {
            selectedPlanID = plans.first?.id
        }
    }

    func selectPlan(_ planID: String) {
        selectedPlanID = planID
        statusMessage = nil
    }

    @discardableResult
    func purchaseSelectedPlan() async -> Bool {
        guard let selectedPlanID else {
            statusMessage = "Select a subscription plan first."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let success = await subscriptionManager.purchase(planID: selectedPlanID)
        syncFromManager()
        if !success {
            statusMessage = loadError ?? "Purchase could not be completed."
        } else {
            statusMessage = nil
        }

        return success
    }

    func restorePurchases() async {
        isLoading = true
        await subscriptionManager.restorePurchases()
        syncFromManager()
        isLoading = false
        statusMessage = loadError
    }

    private func syncFromManager() {
        plans = subscriptionManager.plans
        isSubscribed = subscriptionManager.isSubscribed
        loadError = subscriptionManager.loadError
    }
}
