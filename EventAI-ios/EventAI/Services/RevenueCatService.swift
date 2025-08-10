import Foundation
import RevenueCat
import RevenueCatUI
import UIKit

@MainActor
class RevenueCatService: NSObject, ObservableObject {
    @Published var isPremium = false
    @Published var subscriptionStatus: String = "Free"
    @Published var expiryDate: Date?
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // RevenueCat configuration
    private let apiKey = "YOUR_REVENUECAT_API_KEY" // TODO: Move to secure config
    private let entitlementIdentifier = "premium"
    private let monthlyProductIdentifier = "eventai_premium_monthly"
    
    override init() {
        super.init()
        print("🔧 Initializing RevenueCat service...")
        configureRevenueCat()
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Configuration
    private func configureRevenueCat() {
        // Configure RevenueCat with your API key
        Purchases.configure(withAPIKey: apiKey)
        
        // Set up attribution (optional)
        // Purchases.shared.attribution.setAdjustID("your_adjust_id")
        
        // Set debug logs (remove in production)
        Purchases.logLevel = .debug
        
        // Listen for subscription status changes
        Purchases.shared.delegate = self
        
        print("✅ RevenueCat configured successfully")
    }
    
    // MARK: - User Identity Management
    func setUserIdentity(_ userID: String) async {
        do {
            let (customerInfo, created) = try await Purchases.shared.logIn(userID)
            print("👤 User logged in: \(userID), created: \(created)")
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to set user identity: \(error)")
            purchaseError = "Failed to set user identity"
        }
    }
    
    func logOutUser() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await updateSubscriptionStatus(from: customerInfo)
            print("👤 User logged out")
        } catch {
            print("❌ Failed to log out: \(error)")
        }
    }
    
    // MARK: - Subscription Management
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to get customer info: \(error)")
            purchaseError = "Failed to check subscription status"
        }
    }
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) async {
        // Check if user has premium entitlement
        let hasActiveSubscription = customerInfo.entitlements[entitlementIdentifier]?.isActive == true
        let entitlement = customerInfo.entitlements[entitlementIdentifier]
        
        isPremium = hasActiveSubscription
        expiryDate = entitlement?.expirationDate
        subscriptionStatus = isPremium ? "Premium" : "Free"
        
        print("📊 Subscription status updated:")
        print("   Premium: \(isPremium)")
        print("   Expiry: \(expiryDate?.description ?? "N/A")")
        print("   Product: \(entitlement?.productIdentifier ?? "N/A")")
    }
    
    // MARK: - Purchase Flow
    func purchaseSubscription() async {
        print("🛒 Starting RevenueCat purchase flow...")
        
        isLoading = true
        purchaseError = nil
        
        do {
            // Get available offerings
            let offerings = try await Purchases.shared.offerings()
            
            guard let currentOffering = offerings.current,
                  let monthlyPackage = currentOffering.monthly else {
                print("❌ No monthly offering found")
                purchaseError = "No subscription options available"
                isLoading = false
                return
            }
            
            print("📦 Found monthly package: \(monthlyPackage.storeProduct.localizedTitle) - \(monthlyPackage.storeProduct.localizedPriceString)")
            
            // Attempt purchase
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: monthlyPackage)
            
            // Update subscription status
            await updateSubscriptionStatus(from: customerInfo)
            
            if isPremium {
                print("✅ Purchase successful - Premium activated")
            } else {
                print("⚠️ Purchase completed but premium not active")
                purchaseError = "Purchase completed but premium features not activated. Please restart the app."
            }
            
        } catch let error as ErrorCode {
            print("❌ RevenueCat purchase error: \(error)")
            handlePurchaseError(error)
        } catch {
            print("❌ Unknown purchase error: \(error)")
            purchaseError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func handlePurchaseError(_ error: ErrorCode) {
        print("❌ RevenueCat purchase error: \(error)")
        
        // Handle common cases using string matching
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("cancel") {
            print("👤 User cancelled purchase")
            // Don't set purchaseError for user cancellation
            return
        } else if errorDescription.contains("pending") {
            purchaseError = "Purchase is pending approval"
        } else if errorDescription.contains("not allowed") {
            purchaseError = "Purchases are not allowed on this device"
        } else if errorDescription.contains("network") {
            purchaseError = "Network error - please check your connection"
        } else {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        print("🔄 Restoring purchases...")
        
        isLoading = true
        purchaseError = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await updateSubscriptionStatus(from: customerInfo)
            
            if isPremium {
                print("✅ Purchases restored successfully")
                // Success will be handled by the UI
            } else {
                print("ℹ️ No active subscriptions found")
                purchaseError = "No previous purchases found to restore"
            }
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Customer Center (In-App Management)
    func showCustomerCenter() {
        print("👤 Showing Customer Center...")
        
        // Show Customer Center for subscription management
        if #available(iOS 15.0, *) {
            let customerCenterViewController = CustomerCenterViewController()
            
            // Present from root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(customerCenterViewController, animated: true)
            }
        } else {
            // Fallback for older iOS versions - redirect to App Store
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: - Product Information
    var monthlyPriceString: String {
        guard let monthlyPackage = currentOffering?.monthly else {
            fatalError("Monthly subscription package not available. Ensure offerings are loaded before accessing price.")
        }
        return monthlyPackage.storeProduct.localizedPriceString
    }
    
    // Store the current offerings for price display
    @Published var currentOffering: Offering?
    
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            
            if let monthlyPackage = offerings.current?.monthly {
                print("💰 Monthly price loaded: \(monthlyPackage.storeProduct.localizedPriceString)")
            }
        } catch {
            print("❌ Failed to load offerings: \(error)")
        }
    }
    
    var formattedMonthlyPrice: String {
        guard let monthlyPackage = currentOffering?.monthly else {
            fatalError("Monthly subscription package not available. Ensure offerings are loaded before accessing price.")
        }
        return monthlyPackage.storeProduct.localizedPriceString
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        print("🔄 Received customer info update from RevenueCat")
        Task {
            await updateSubscriptionStatus(from: customerInfo)
        }
    }
    
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        print("🎁 Promotional product ready: \(product.localizedTitle)")
        // Handle promotional purchases if needed
        startPurchase { (transaction, customerInfo, error, cancelled) in
            if let error = error {
                print("❌ Promotional purchase failed: \(error)")
            } else if !cancelled {
                print("✅ Promotional purchase successful")
            }
        }
    }
}