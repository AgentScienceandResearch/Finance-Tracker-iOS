import Foundation
import StoreKit

@MainActor
protocol SubscriptionRepositorying: AnyObject {
    func loadProducts(productIDs: [String]) async throws -> [Product]
    func purchase(_ product: Product) async throws -> Product.PurchaseResult
    func syncPurchases() async throws
    func currentEntitledProductIDs() async -> Set<String>
    func transactionUpdates() -> AsyncStream<VerificationResult<Transaction>>
}

@MainActor
final class StoreKitSubscriptionRepository: SubscriptionRepositorying {
    func loadProducts(productIDs: [String]) async throws -> [Product] {
        try await Product.products(for: productIDs)
    }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }

    func syncPurchases() async throws {
        try await AppStore.sync()
    }

    func currentEntitledProductIDs() async -> Set<String> {
        var ids = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            ids.insert(transaction.productID)
        }

        return ids
    }

    func transactionUpdates() -> AsyncStream<VerificationResult<Transaction>> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    continuation.yield(result)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
