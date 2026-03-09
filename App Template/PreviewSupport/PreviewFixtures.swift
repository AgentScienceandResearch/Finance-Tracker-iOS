import Foundation

#if DEBUG
@MainActor
final class PreviewAuthenticationManagerMock: AuthenticationManaging {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?

    func signInWithEmail(_ email: String, password: String) async {}
    func signUp(email: String, password: String, displayName: String) async {}
    func signOut() {}
}

@MainActor
enum AuthenticationPreviewFixtures {
    static func signInFlow() -> AuthenticationFlowViewModel {
        let manager = PreviewAuthenticationManagerMock()
        let flow = AuthenticationFlowViewModel(authManager: manager)
        flow.email = "pilot@example.com"
        flow.password = "password123"
        return flow
    }

    static func signUpErrorFlow() -> AuthenticationFlowViewModel {
        let manager = PreviewAuthenticationManagerMock()
        manager.errorMessage = "Email already in use"
        let flow = AuthenticationFlowViewModel(authManager: manager)
        flow.isSignUp = true
        flow.email = "pilot@example.com"
        flow.password = "password123"
        flow.displayName = "Dakota"
        flow.inlineError = manager.errorMessage
        return flow
    }

    static func submittingFlow() -> AuthenticationFlowViewModel {
        let manager = PreviewAuthenticationManagerMock()
        let flow = AuthenticationFlowViewModel(authManager: manager)
        flow.email = "pilot@example.com"
        flow.password = "password123"
        flow.isSubmitting = true
        return flow
    }
}

@MainActor
final class PreviewSubscriptionManagerMock: SubscriptionManaging {
    var isSubscribed: Bool
    var isLoading: Bool
    var loadError: String?
    var plans: [SubscriptionPlan]

    init(
        isSubscribed: Bool = false,
        isLoading: Bool = false,
        loadError: String? = nil,
        plans: [SubscriptionPlan] = []
    ) {
        self.isSubscribed = isSubscribed
        self.isLoading = isLoading
        self.loadError = loadError
        self.plans = plans
    }

    func loadProducts(forceReload: Bool) async {}
    func purchase(planID: String) async -> Bool { true }
    func restorePurchases() async {}
}

@MainActor
enum PaywallPreviewFixtures {
    static let samplePlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "monthly",
            title: "Monthly",
            billingPeriod: "1 month",
            displayPrice: "$9.99",
            pricePerMonth: "~$9.99/mo"
        ),
        SubscriptionPlan(
            id: "yearly",
            title: "Yearly",
            billingPeriod: "1 year",
            displayPrice: "$79.99",
            pricePerMonth: "~$6.67/mo"
        )
    ]

    static func loadedFlow() -> PaywallFlowViewModel {
        let manager = PreviewSubscriptionManagerMock(plans: samplePlans)
        let flow = PaywallFlowViewModel(subscriptionManager: manager)
        flow.selectPlan("yearly")
        return flow
    }

    static func loadingFlow() -> PaywallFlowViewModel {
        let manager = PreviewSubscriptionManagerMock(isLoading: true)
        return PaywallFlowViewModel(subscriptionManager: manager)
    }

    static func errorFlow() -> PaywallFlowViewModel {
        let manager = PreviewSubscriptionManagerMock(loadError: "Unable to reach the App Store")
        let flow = PaywallFlowViewModel(subscriptionManager: manager)
        flow.statusMessage = "Unable to reach the App Store"
        return flow
    }
}
#endif
