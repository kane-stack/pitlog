import Foundation
import PitlogCore
import StoreKit

/// The real StoreKit 2 backend. Stateless: every call asks StoreKit, which caches on its own.
struct StoreKitBackend: StoreBackend {
    func currentEntitlements() async -> EntitlementSnapshot {
        var records: [PurchaseRecord] = []
        var sawUnverified = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard ProProduct.all.contains(transaction.productID) else { continue }
                records.append(
                    PurchaseRecord(
                        productID: transaction.productID,
                        revocationDate: transaction.revocationDate,
                        expirationDate: transaction.expirationDate,
                        ownership: transaction.ownershipType == .familyShared ? .familyShared : .purchased))
            case .unverified(let transaction, _):
                if ProProduct.all.contains(transaction.productID) { sawUnverified = true }
            }
        }
        return EntitlementSnapshot(records: records, sawUnverified: sawUnverified)
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func loadProducts() async throws -> [StoreProduct] {
        let products = try await Product.products(for: Array(ProProduct.all))
        var result: [StoreProduct] = []
        for product in products {
            var trial: StoreProduct.Period?
            if let subscription = product.subscription,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial
            {
                // Only users who never had an introductory offer of this group get the free trial.
                let eligible = await subscription.isEligibleForIntroOffer
                if eligible { trial = Self.period(offer.period) }
            }
            result.append(
                StoreProduct(
                    id: product.id,
                    kind: product.type == .autoRenewable ? .subscription : .lifetime,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    isFamilyShareable: product.isFamilyShareable,
                    period: product.subscription.map { Self.period($0.subscriptionPeriod) },
                    freeTrial: trial))
        }
        // The subscription first, then the lifetime purchase.
        return result.sorted { lhs, rhs in
            (lhs.kind == .subscription ? 0 : 1) < (rhs.kind == .subscription ? 0 : 1)
        }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return .success
            case .unverified:
                throw StoreError.unverified
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    private static func period(_ period: Product.SubscriptionPeriod) -> StoreProduct.Period {
        let unit: StoreProduct.Period.Unit =
            switch period.unit {
            case .day: .day
            case .week: .week
            case .month: .month
            case .year: .year
            @unknown default: .year
            }
        return StoreProduct.Period(value: period.value, unit: unit)
    }
}
