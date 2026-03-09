import Foundation

@MainActor
protocol SubscriptionManaging: AnyObject {
    var isSubscribed: Bool { get }
    var isLoading: Bool { get }
    var loadError: String? { get }
    var plans: [SubscriptionPlan] { get }

    func loadProducts(forceReload: Bool) async
    func purchase(planID: String) async -> Bool
    func restorePurchases() async
}
