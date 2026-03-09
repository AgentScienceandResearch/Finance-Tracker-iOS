import XCTest
import StoreKit

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
@MainActor
final class SubscriptionManagerTests: XCTestCase {
    final class MockRepository: SubscriptionRepositorying {
        var loadProductsError: Error?
        var syncError: Error?
        var entitledProductIDs = Set<String>()

        func loadProducts(productIDs: [String]) async throws -> [Product] {
            if let loadProductsError {
                throw loadProductsError
            }
            return []
        }

        func purchase(_ product: Product) async throws -> Product.PurchaseResult {
            XCTFail("purchase(_:) should not be called in this test")
            throw StubError.unexpectedCall
        }

        func syncPurchases() async throws {
            if let syncError {
                throw syncError
            }
        }

        func currentEntitledProductIDs() async -> Set<String> {
            entitledProductIDs
        }

        func transactionUpdates() -> AsyncStream<VerificationResult<Transaction>> {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    enum StubError: Error {
        case loadFailed
        case syncFailed
        case unexpectedCall
    }

    func testLoadProductsFailureSetsError() async {
        let repo = MockRepository()
        repo.loadProductsError = StubError.loadFailed
        let manager = SubscriptionManager.makeForTesting(repository: repo)

        await manager.loadProducts(forceReload: true)

        XCTAssertFalse(manager.productsLoaded)
        XCTAssertNotNil(manager.loadError)
    }

    func testPurchaseWithUnknownPlanFailsFast() async {
        let repo = MockRepository()
        let manager = SubscriptionManager.makeForTesting(repository: repo)

        let success = await manager.purchase(planID: "missing_plan")

        XCTAssertFalse(success)
        XCTAssertEqual(manager.loadError, "Selected subscription plan is unavailable.")
    }

    func testRestoreFailureSetsError() async {
        let repo = MockRepository()
        repo.syncError = StubError.syncFailed
        let manager = SubscriptionManager.makeForTesting(repository: repo)

        await manager.restorePurchases()

        XCTAssertNotNil(manager.loadError)
    }
}
#endif
