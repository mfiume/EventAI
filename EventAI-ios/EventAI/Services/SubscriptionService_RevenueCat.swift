import Foundation
import RevenueCat
import RevenueCatUI

/// RevenueCat-powered subscription service that maintains the same interface as the original SubscriptionService
/// This allows for easy A/B testing and switching between StoreKit and RevenueCat implementations
@MainActor
class SubscriptionService_RevenueCat: ObservableObject {
    // Published properties - same interface as original SubscriptionService
    @Published var isPremium = false
    @Published var subscriptionStatus: String = "Free"
    @Published var expiryDate: Date?
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // RevenueCat configuration
    private let apiKey = "YOUR_REVENUECAT_API_KEY" // TODO: Replace with actual key from RevenueCat dashboard
    private let entitlementIdentifier = "premium"
    
    // Store current offerings for price display
    @Published private var currentOffering: Offering?
    
    init() {
        print("🔧 Initializing RevenueCat SubscriptionService...")
        configureRevenueCat()
        Task {
            await loadOfferings()
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - RevenueCat Configuration
    private func configureRevenueCat() {
        // Configure RevenueCat
        Purchases.configure(withAPIKey: apiKey)
        
        // Set debug logs for development (disable in production)
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        
        // Set up delegate for subscription updates
        Purchases.shared.delegate = self
        
        print("✅ RevenueCat configured with API key")
    }
    
    // MARK: - Public Interface (matches original SubscriptionService)
    
    func purchaseSubscription() async {
        print("🛒 Starting RevenueCat subscription purchase...")
        
        isLoading = true
        purchaseError = nil
        
        do {
            // Get current offerings
            let offerings = try await Purchases.shared.offerings()
            
            guard let currentOffering = offerings.current,
                  let monthlyPackage = currentOffering.monthly else {
                print("❌ No monthly subscription package available")
                purchaseError = "Subscription not available. Please try again later."
                isLoading = false
                return
            }
            
            print("📦 Purchasing package: \(monthlyPackage.storeProduct.displayName) - \(monthlyPackage.storeProduct.displayPrice)")
            
            // Perform the purchase
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: monthlyPackage)
            
            // Update subscription status from the result
            await updateSubscriptionStatus(from: customerInfo)
            
            print("✅ Purchase flow completed - Premium: \(isPremium)")
            
        } catch let error as ErrorCode {
            print("❌ RevenueCat purchase error: \(error)")
            handleRevenueCatError(error)
        } catch {
            print("❌ Unknown purchase error: \(error)")
            purchaseError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        print("🔄 Restoring purchases via RevenueCat...")
        
        isLoading = true
        purchaseError = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await updateSubscriptionStatus(from: customerInfo)
            
            if isPremium {
                print("✅ Purchases restored successfully - Premium active")
            } else {
                print("ℹ️ No active subscriptions found during restore")
                purchaseError = "No previous purchases found to restore."
            }
            
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func checkSubscriptionStatus() async {
        print("📊 Checking subscription status via RevenueCat...")
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to get customer info: \(error)")
            // Don't set purchaseError for status checks - just log
        }
    }
    
    // Price string property - matches original interface
    var monthlyPriceString: String {
        if let monthlyPackage = currentOffering?.monthly {
            return monthlyPackage.storeProduct.displayPrice
        }
        return "$4.99" // Fallback price
    }
    
    // MARK: - RevenueCat Customer Center Integration
    
    /// Show RevenueCat Customer Center for in-app subscription management
    /// This is a RevenueCat-specific feature that provides native subscription management UI
    func showCustomerCenter() {
        print("👤 Showing RevenueCat Customer Center...")
        
        if #available(iOS 15.0, *) {
            let customerCenterViewController = CustomerCenterViewController()
            
            // Present from the current window's root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Find the top-most presented view controller
                var topViewController = rootViewController
                while let presentedViewController = topViewController.presentedViewController {
                    topViewController = presentedViewController
                }
                
                topViewController.present(customerCenterViewController, animated: true)
            }
        } else {
            // Fallback for iOS 14 and earlier - redirect to App Store subscription management
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: - User Identity Management (RevenueCat-specific)
    
    /// Link user identity with RevenueCat for cross-platform subscription sharing
    func setUserIdentity(_ userID: String) async {
        print("👤 Setting RevenueCat user identity: \(userID)")
        
        do {
            let (customerInfo, created) = try await Purchases.shared.logIn(userID)
            print("✅ User identity set - Created: \(created)")
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to set user identity: \(error)")
            purchaseError = "Failed to link user account"
        }
    }
    
    /// Log out current user (useful for testing or account switching)
    func logOutUser() async {
        print("👤 Logging out RevenueCat user...")
        
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await updateSubscriptionStatus(from: customerInfo)
            print("✅ User logged out successfully")
        } catch {
            print("❌ Failed to log out user: \(error)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            
            if let monthlyPackage = currentOffering?.monthly {
                print("💰 Monthly subscription loaded: \(monthlyPackage.storeProduct.displayName) - \(monthlyPackage.storeProduct.displayPrice)")
            } else {
                print("⚠️ No monthly subscription package found in offerings")
            }
            
        } catch {
            print("❌ Failed to load RevenueCat offerings: \(error)")
        }
    }
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) async {
        // Check the premium entitlement
        let premiumEntitlement = customerInfo.entitlements[entitlementIdentifier]
        let hasActiveSubscription = premiumEntitlement?.isActive == true
        
        // Update published properties
        isPremium = hasActiveSubscription
        expiryDate = premiumEntitlement?.expirationDate
        subscriptionStatus = isPremium ? "Premium" : "Free"
        
        // Debug logging
        print("📊 Subscription status updated:")
        print("   Premium: \(isPremium)")
        print("   Status: \(subscriptionStatus)")
        print("   Expires: \(expiryDate?.description ?? "N/A")")
        print("   Product: \(premiumEntitlement?.productIdentifier ?? "N/A")")
        print("   Entitlements: \(customerInfo.entitlements.active.keys)")
    }
    
    private func handleRevenueCatError(_ error: ErrorCode) {
        switch error {
        case .userCancelledError:
            print("👤 User cancelled purchase")
            // Don't show error message for user cancellation
            break
            
        case .paymentPendingError:
            print("⏳ Payment pending approval")
            purchaseError = "Purchase is pending approval"
            
        case .purchaseNotAllowedError:
            print("🚫 Purchases not allowed")
            purchaseError = "Purchases are not allowed on this device"
            
        case .purchaseInvalidError:
            print("❌ Invalid purchase")
            purchaseError = "Purchase failed - invalid product"
            
        case .networkError:
            print("🌐 Network error")
            purchaseError = "Network error - please check your connection and try again"
            
        case .receiptAlreadyInUseError:
            print("🔄 Receipt already in use")
            purchaseError = "This purchase is already associated with another account"
            
        default:
            print("❌ Other RevenueCat error: \(error)")
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionService_RevenueCat: PurchasesDelegate {
    /// Called when RevenueCat receives updated customer information
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        print("🔄 RevenueCat customer info updated")
        Task {
            await updateSubscriptionStatus(from: customerInfo)
        }
    }
    
    /// Called when a promotional offer becomes available
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        print("🎁 Promotional product available: \(product.localizedTitle)")
        
        // Auto-handle promotional purchases
        startPurchase { (transaction, customerInfo, error, cancelled) in
            Task {
                if let error = error {
                    print("❌ Promotional purchase failed: \(error)")
                    await MainActor.run {
                        self.purchaseError = "Promotional purchase failed"
                    }
                } else if !cancelled, let customerInfo = customerInfo {
                    print("✅ Promotional purchase successful")
                    await self.updateSubscriptionStatus(from: customerInfo)
                }
            }
        }
    }
}