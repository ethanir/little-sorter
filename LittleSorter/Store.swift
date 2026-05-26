import Foundation
import Combine
import StoreKit

@MainActor
final class Store: ObservableObject {
    // Matches your bundle ID com.ethanirimiciuc.LittleSorter
    let unlockID = "com.ethanirimiciuc.LittleSorter.unlockall"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs = Set<String>()
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var isUnlocked: Bool { purchasedIDs.contains(unlockID) }
    var unlockProduct: Product? { products.first { $0.id == unlockID } }

    /// True once the real product has loaded from the App Store. The paywall uses
    /// this to show a loader and keep the buy button disabled until then.
    var isProductLoaded: Bool { unlockProduct != nil }

    /// The real localized price, or `nil` if the product hasn't loaded yet. We never
    /// fall back to a hardcoded "$2.99" — that would show a wrong/fake price in any
    /// non-US storefront, or when the product fails to load.
    var priceText: String? { unlockProduct?.displayPrice }

    init() {
        updatesTask = observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshPurchased()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        lastError = nil
        do {
            products = try await Product.products(for: [unlockID])
            if products.isEmpty {
                lastError = "Couldn’t load the store. Please check your connection."
            }
        } catch {
            lastError = "Couldn’t load the store. Please check your connection."
        }
    }

    func purchase() async {
        guard let product = unlockProduct else {
            lastError = "The store isn’t ready yet. Please try again."
            return
        }
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshPurchased()
                case .unverified:
                    // Apple couldn't verify the transaction signature — don't unlock.
                    lastError = "Couldn’t verify the purchase."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshPurchased()
            if !isUnlocked {
                lastError = "No purchases found to restore."
            }
        } catch {
            lastError = "Restore failed. Please try again."
        }
    }

    func refreshPurchased() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        purchasedIDs = ids
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshPurchased()
                }
            }
        }
    }
}
