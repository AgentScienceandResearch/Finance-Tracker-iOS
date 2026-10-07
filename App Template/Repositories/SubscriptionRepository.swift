import Foundation
import StoreKit

@MainActor
protocol SubscriptionRepositorying: AnyObject {
    func loadProducts(productIDs: [String]) async throws -> [Product]
    func purchase(_ product: Product) async throws -> Product.PurchaseResult
    func syncPurchases() async throws
    func currentEntitledProductIDs() async -> Set<String>
    func currentEntitlementJWS(for productIDs: [String]) async -> String?
    func transactionUpdates() -> AsyncStream<VerificationResult<Transaction>>
}

extension SubscriptionRepositorying {
    func currentEntitlementJWS(for productIDs: [String]) async -> String? { nil }
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

    /// Signed transaction the AI server verifies with Apple's certificates. Uses the
    /// entitlement that expires last when more than one is active.
    func currentEntitlementJWS(for productIDs: [String]) async -> String? {
        var latest: (expires: Date, jws: String)?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            let expires = transaction.expirationDate ?? .distantFuture
            if latest == nil || expires > latest!.expires {
                latest = (expires, result.jwsRepresentation)
            }
        }

        return latest?.jws
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
