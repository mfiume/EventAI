import StoreKit
import Foundation

@MainActor
class SubscriptionService: ObservableObject {
    @Published var isPremium = false
    @Published var subscriptionStatus: String = "Free"
    @Published var expiryDate: Date?
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // Product IDs - these need to be configured in App Store Connect
    private let monthlySubscriptionID = "eventai_premium_monthly"
    
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        print("🔧 Initializing SubscriptionService...")
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    private func loadProducts() async {
        print("🔧 Loading products for ID: \(monthlySubscriptionID)")
        do {
            products = try await Product.products(for: [monthlySubscriptionID])
            print("✅ Loaded \(products.count) products")
            
            for product in products {
                print("📦 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                print("   Type: \(product.type), Available: \(product.subscription != nil)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase Flow
    func purchaseSubscription() async {
        print("🛒 Starting subscription purchase flow...")
        
        guard let product = products.first(where: { $0.id == monthlySubscriptionID }) else {
            print("❌ Product not found. Available products: \(products.map { $0.id })")
            purchaseError = "Product not found. Please try again."
            return
        }
        
        print("📦 Using product: \(product.displayName) - \(product.displayPrice)")
        
        isLoading = true
        purchaseError = nil
        
        do {
            print("💳 Initiating purchase...")
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                print("✅ Purchase successful, verifying...")
                let transaction = try checkVerified(verificationResult)
                print("✅ Transaction verified: \(transaction.id)")
                await updateSubscriptionStatus()
                await transaction.finish()
                print("✅ Transaction finished")
                
            case .userCancelled:
                print("👤 User cancelled purchase")
                
            case .pending:
                print("⏳ Purchase pending approval")
                purchaseError = "Purchase is pending approval"
                
            @unknown default:
                print("❓ Unknown purchase result")
                purchaseError = "Unknown purchase result"
            }
            
        } catch {
            print("❌ Purchase failed: \(error)")
            purchaseError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            purchaseError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    func checkSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    private func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var latestExpiry: Date?
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == monthlySubscriptionID {
                    hasActiveSubscription = true
                    
                    // For subscriptions, calculate expiry date
                    if let expirationDate = transaction.expirationDate {
                        latestExpiry = expirationDate
                    }
                }
                
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }
        
        isPremium = hasActiveSubscription
        expiryDate = latestExpiry
        subscriptionStatus = isPremium ? "Premium" : "Free"
        
        print("📊 Subscription status updated - Premium: \(isPremium)")
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Info
    var monthlyProduct: Product? {
        return products.first { $0.id == monthlySubscriptionID }
    }
    
    var monthlyPriceString: String? {
        return monthlyProduct?.displayPrice
    }
}

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase"
        }
    }
}