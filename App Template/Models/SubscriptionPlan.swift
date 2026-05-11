import Foundation

struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let title: String
    let billingPeriod: String
    let displayPrice: String
    let pricePerMonth: String?
    let trialDuration: String?
    let savingsLabel: String?
}
