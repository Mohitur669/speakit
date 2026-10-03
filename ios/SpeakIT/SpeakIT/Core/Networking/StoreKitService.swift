//
//  StoreKitService.swift
//  SpeakIT
//
//  StoreKit 2 service handling in-app purchases, subscriptions, entitlements, and transaction updates.
//

import Foundation
import StoreKit

enum StoreKitError: LocalizedError {
    case unverifiedTransaction
    case userCancelled
    case pending
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "The transaction could not be verified by Apple."
        case .userCancelled:
            return "Purchase was cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .productNotFound:
            return "Subscription product could not be found."
        }
    }
}

@Observable
final class StoreKitService {
    static let shared = StoreKitService()
    
    static let proProductID = "com.speakit.pro"
    static let proPlusProductID = "com.speakit.proplus"
    
    var products: [Product] = []
    var isPurchasing: Bool = false
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    private init() {
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    @MainActor
    func loadProducts() async {
        do {
            let fetchedProducts = try await Product.products(for: [
                Self.proProductID,
                Self.proPlusProductID
            ])
            self.products = fetchedProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to load StoreKit products: \(error)")
        }
    }
    
    func product(for plan: PlanType) -> Product? {
        switch plan {
        case .pro:
            return products.first(where: { $0.id == Self.proProductID })
        case .proPlus:
            return products.first(where: { $0.id == Self.proPlusProductID })
        default:
            return nil
        }
    }
    
    // MARK: - Purchase Product
    @MainActor
    func purchase(_ product: Product) async throws -> Transaction {
        isPurchasing = true
        defer { isPurchasing = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreKitError.unverifiedTransaction
            }
            
            let doublePrice = Double(truncating: product.price as NSNumber)
            let currCode = product.priceFormatStyle.currencyCode
            
            // Notify backend so it updates planType in the DB with accurate StoreKit pricing.
            // Must happen before finish() to ensure plan is updated atomically.
            try await notifyBackend(
                transaction: transaction,
                productId: product.id,
                amount: doublePrice,
                currency: currCode
            )
            
            // Deliver content / finish transaction
            await transaction.finish()
            return transaction
            
        case .userCancelled:
            throw StoreKitError.userCancelled
            
        case .pending:
            throw StoreKitError.pending
            
        @unknown default:
            throw StoreKitError.unverifiedTransaction
        }
    }
    
    // MARK: - Backend Plan Sync
    /// Sends the Apple transactionId + productId to the backend so it can update
    /// the user's planType in the database. This is the critical link between
    /// Apple's sandbox purchase and SpeakIT's subscription state.
    private func notifyBackend(
        transaction: Transaction,
        productId: String,
        amount: Double? = nil,
        currency: String? = nil
    ) async throws {
        struct AppleVerifyBody: Encodable {
            let transactionId: String
            let productId: String
            let originalTransactionId: String
            let amount: Double?
            let currency: String?
        }
        let body = try JSONEncoder().encode(AppleVerifyBody(
            transactionId: String(transaction.id),
            productId: productId,
            originalTransactionId: String(transaction.originalID),
            amount: amount,
            currency: currency
        ))
        let _: String = try await HTTPClient.shared.requestString(
            .appleVerifyPurchase,
            method: "POST",
            body: body
        )
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    guard case .verified(let transaction) = result else {
                        continue
                    }
                    await transaction.finish()
                } catch {
                    print("Transaction update listener error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
    }
}
