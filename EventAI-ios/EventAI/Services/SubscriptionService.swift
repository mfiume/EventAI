import StoreKit
import Foundation

@MainActor
class SubscriptionService_StoreKit: ObservableObject {
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
        print("📊 Current state - Products loaded: \(products.count), isPremium: \(isPremium)")
        
        // Wait a moment for products to load if they haven't yet
        if products.isEmpty {
            print("⏳ Products not loaded yet, waiting...")
            await loadProducts()
            
            // Give a short delay for products to be available
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        guard let product = products.first(where: { $0.id == monthlySubscriptionID }) else {
            print("❌ Product not found. Available products: \(products.map { $0.id })")
            print("📦 All products details:")
            for prod in products {
                print("   - \(prod.id): \(prod.displayName) (\(prod.displayPrice))")
            }
            
            purchaseError = "Subscription product not available. Please check your App Store connection and try again."
            return
        }
        
        print("📦 Using product: \(product.displayName) - \(product.displayPrice)")
        print("🔍 Product details: ID=\(product.id), Type=\(product.type)")
        
        isLoading = true
        purchaseError = nil
        
        do {
            print("💳 Initiating purchase...")
            
            // Check if user can make purchases
            guard AppStore.canMakePayments else {
                print("❌ User cannot make payments")
                purchaseError = "In-app purchases are not available. Please check your device settings."
                isLoading = false
                return
            }
            
            let result = try await product.purchase()
            print("🔄 Purchase result received: \(result)")
            
            switch result {
            case .success(let verificationResult):
                print("✅ Purchase successful, verifying...")
                let transaction = try checkVerified(verificationResult)
                print("✅ Transaction verified: \(transaction.id)")
                print("📅 Transaction details - Product: \(transaction.productID), Date: \(transaction.purchaseDate)")
                
                await updateSubscriptionStatus()
                await transaction.finish()
                print("✅ Transaction finished")
                
            case .userCancelled:
                print("👤 User cancelled purchase")
                // Don't set error for user cancellation
                
            case .pending:
                print("⏳ Purchase pending approval")
                purchaseError = "Purchase is pending approval. Please check your payment method."
                
            @unknown default:
                print("❓ Unknown purchase result: \(result)")
                purchaseError = "Unknown purchase result. Please try again or contact support."
            }
            
        } catch {
            print("❌ Purchase failed: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        
        isLoading = false
        print("🏁 Purchase flow completed - isPremium: \(isPremium), hasError: \(purchaseError != nil)")
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        print("🔄 Starting restore purchases...")
        isLoading = true
        purchaseError = nil
        
        do {
            print("🔄 Syncing with App Store...")
            try await AppStore.sync()
            print("✅ App Store sync completed")
            
            await updateSubscriptionStatus()
            print("📊 Subscription status updated after restore - isPremium: \(isPremium)")
            
            if !isPremium {
                // Check if we have any transactions at all
                var hasAnyTransactions = false
                for await result in Transaction.all {
                    hasAnyTransactions = true
                    do {
                        let transaction = try checkVerified(result)
                        print("🔍 Found transaction: \(transaction.productID) - \(transaction.purchaseDate)")
                    } catch {
                        print("❌ Failed to verify transaction during restore: \(error)")
                    }
                }
                
                if !hasAnyTransactions {
                    purchaseError = "No previous purchases found to restore."
                } else {
                    purchaseError = "No active subscriptions found. Previous purchases may have expired."
                }
            }
            
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            print("🔍 Restore error details: \(error.localizedDescription)")
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
        print("🏁 Restore purchases completed - isPremium: \(isPremium)")
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