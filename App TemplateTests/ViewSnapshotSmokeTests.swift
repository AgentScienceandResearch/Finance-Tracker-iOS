import XCTest
import SwiftUI

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
@MainActor
final class ViewSnapshotSmokeTests: XCTestCase {
    final class AuthMock: AuthenticationManaging {
        var isAuthenticated = false
        var isLoading = false
        var errorMessage: String?
        func signInWithEmail(_ email: String, password: String) async {}
        func signUp(email: String, password: String, displayName: String) async {}
        func signOut() {}
    }

    final class SubscriptionMock: SubscriptionManaging {
        var isSubscribed = false
        var isLoading = false
        var loadError: String?
        var plans: [SubscriptionPlan]

        init(plans: [SubscriptionPlan]) {
            self.plans = plans
        }

        func loadProducts(forceReload: Bool) async {}
        func purchase(planID: String) async -> Bool { true }
        func restorePurchases() async {}
    }

    func testAuthenticationViewRendersToImage() {
        let manager = AuthMock()
        let flow = AuthenticationFlowViewModel(authManager: manager)
        flow.email = "sample@example.com"
        flow.password = "password123"

        let image = render(
            AuthenticationView(flow: flow)
                .frame(width: 390, height: 844)
        )

        XCTAssertNotNil(image)
    }

    func testPaywallViewRendersToImage() {
        let plans = [
            SubscriptionPlan(id: "monthly", title: "Monthly", billingPeriod: "1 month", displayPrice: "$9.99", pricePerMonth: "~$9.99/mo")
        ]
        let manager = SubscriptionMock(plans: plans)
        let flow = PaywallFlowViewModel(subscriptionManager: manager)
        flow.selectPlan("monthly")

        let image = render(
            PaywallView(flow: flow)
                .frame(width: 390, height: 844)
        )

        XCTAssertNotNil(image)
    }

    private func render<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}
#endif
