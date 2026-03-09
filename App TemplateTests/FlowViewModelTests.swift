import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
@MainActor
final class FlowViewModelTests: XCTestCase {
    final class MockAuthManager: AuthenticationManaging {
        var isAuthenticated = false
        var isLoading = false
        var errorMessage: String?

        var lastSignInEmail: String?
        var lastSignInPassword: String?
        var signInCallCount = 0

        var lastSignUpEmail: String?
        var lastSignUpPassword: String?
        var lastSignUpDisplayName: String?
        var signUpCallCount = 0

        func signInWithEmail(_ email: String, password: String) async {
            signInCallCount += 1
            lastSignInEmail = email
            lastSignInPassword = password
        }

        func signUp(email: String, password: String, displayName: String) async {
            signUpCallCount += 1
            lastSignUpEmail = email
            lastSignUpPassword = password
            lastSignUpDisplayName = displayName
        }

        func signOut() {
            isAuthenticated = false
        }
    }

    final class MockSubscriptionManager: SubscriptionManaging {
        var isSubscribed = false
        var isLoading = false
        var loadError: String?
        var plans: [SubscriptionPlan]

        var didLoadProducts = false
        var lastLoadForceReload = false
        var lastPurchasedPlanID: String?
        var purchaseResult = false
        var restoreCalled = false

        init(plans: [SubscriptionPlan]) {
            self.plans = plans
        }

        func loadProducts(forceReload: Bool) async {
            didLoadProducts = true
            lastLoadForceReload = forceReload
        }

        func purchase(planID: String) async -> Bool {
            lastPurchasedPlanID = planID
            return purchaseResult
        }

        func restorePurchases() async {
            restoreCalled = true
        }
    }

    func testAuthenticationFlowRejectsInvalidInputBeforeManagerCall() async {
        let authManager = MockAuthManager()
        let viewModel = AuthenticationFlowViewModel(authManager: authManager)
        viewModel.email = "bad-email"
        viewModel.password = "123"

        let success = await viewModel.submit()

        XCTAssertFalse(success)
        XCTAssertEqual(authManager.signInCallCount, 0)
        XCTAssertNotNil(viewModel.inlineError)
    }

    func testAuthenticationFlowSignInSuccess() async {
        let authManager = MockAuthManager()
        authManager.isAuthenticated = true
        let viewModel = AuthenticationFlowViewModel(authManager: authManager)
        viewModel.email = "hello@example.com"
        viewModel.password = "password123"

        let success = await viewModel.submit()

        XCTAssertTrue(success)
        XCTAssertEqual(authManager.signInCallCount, 1)
        XCTAssertEqual(authManager.lastSignInEmail, "hello@example.com")
    }

    func testAuthenticationFlowSignUpTrimsDisplayName() async {
        let authManager = MockAuthManager()
        authManager.isAuthenticated = true
        let viewModel = AuthenticationFlowViewModel(authManager: authManager)
        viewModel.toggleMode()
        viewModel.email = "new@example.com"
        viewModel.password = "password123"
        viewModel.displayName = "  Dakota  "

        let success = await viewModel.submit()

        XCTAssertTrue(success)
        XCTAssertEqual(authManager.signUpCallCount, 1)
        XCTAssertEqual(authManager.lastSignUpDisplayName, "Dakota")
    }

    func testPaywallFlowLoadsPlansAndAutoSelectsFirst() async {
        let plans = [
            SubscriptionPlan(id: "monthly", title: "Monthly", billingPeriod: "1 month", displayPrice: "$9.99", pricePerMonth: "$9.99/mo"),
            SubscriptionPlan(id: "yearly", title: "Yearly", billingPeriod: "1 year", displayPrice: "$79.99", pricePerMonth: "$6.67/mo")
        ]
        let manager = MockSubscriptionManager(plans: plans)
        let viewModel = PaywallFlowViewModel(subscriptionManager: manager)

        await viewModel.loadPlans()

        XCTAssertTrue(manager.didLoadProducts)
        XCTAssertFalse(manager.lastLoadForceReload)
        XCTAssertEqual(viewModel.selectedPlanID, "monthly")
    }

    func testPaywallFlowPurchaseRequiresSelection() async {
        let manager = MockSubscriptionManager(plans: [])
        let viewModel = PaywallFlowViewModel(subscriptionManager: manager)

        let success = await viewModel.purchaseSelectedPlan()

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.statusMessage, "Select a subscription plan first.")
        XCTAssertNil(manager.lastPurchasedPlanID)
    }

    func testPaywallFlowPurchaseForwardsSelectedPlanID() async {
        let manager = MockSubscriptionManager(plans: [
            SubscriptionPlan(id: "monthly", title: "Monthly", billingPeriod: "1 month", displayPrice: "$9.99", pricePerMonth: nil)
        ])
        manager.purchaseResult = true

        let viewModel = PaywallFlowViewModel(subscriptionManager: manager)
        viewModel.selectPlan("monthly")

        let success = await viewModel.purchaseSelectedPlan()

        XCTAssertTrue(success)
        XCTAssertEqual(manager.lastPurchasedPlanID, "monthly")
        XCTAssertNil(viewModel.statusMessage)
    }

    func testPaywallFlowRestoreSurfacesErrors() async {
        let manager = MockSubscriptionManager(plans: [])
        manager.loadError = "Nothing to restore"
        let viewModel = PaywallFlowViewModel(subscriptionManager: manager)

        await viewModel.restorePurchases()

        XCTAssertTrue(manager.restoreCalled)
        XCTAssertEqual(viewModel.statusMessage, "Nothing to restore")
    }
}
#endif
