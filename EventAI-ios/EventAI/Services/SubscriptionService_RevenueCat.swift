import Foundation
import RevenueCat
import RevenueCatUI
import UIKit

/// RevenueCat-powered subscription service that maintains the same interface as the original SubscriptionService
/// This allows for easy A/B testing and switching between StoreKit and RevenueCat implementations
@MainActor
class SubscriptionService_RevenueCat: NSObject, ObservableObject {
    // Published properties - same interface as original SubscriptionService
    @Published var isPremium = false
    @Published var subscriptionStatus: String = "Free"
    @Published var expiryDate: Date?
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // RevenueCat configuration - using centralized config
    private let apiKey = RevenueCatConfig.publicAPIKey
    private let entitlementIdentifier = RevenueCatConfig.premiumEntitlementID
    
    // Store current offerings for price display
    @Published private var currentOffering: Offering?
    
    override init() {
        super.init()
        configureRevenueCat()
        Task {
            await loadOfferings()
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - RevenueCat Configuration
    private func configureRevenueCat() {
        // Validate configuration before initializing
        let configErrors = RevenueCatConfig.validateConfiguration()
        if !configErrors.isEmpty {
            print("⚠️ RevenueCat Configuration Issues:")
            configErrors.forEach { print("   - \($0)") }
            print("   See RevenueCatConfig.swift for setup instructions")
            // Continue anyway to get more detailed error messages
        }
        
        // Configure RevenueCat with proper error handling
        Purchases.configure(withAPIKey: apiKey)
        
        // Disable debug logs to reduce console noise
        Purchases.logLevel = .error
        
        // Set up delegate for subscription updates
        Purchases.shared.delegate = self
    }
    
    // MARK: - Public Interface (matches original SubscriptionService)
    
    func purchaseSubscription() async {
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
            
            // Perform the purchase
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: monthlyPackage)
            
            // Update subscription status from the result
            await updateSubscriptionStatus(from: customerInfo)
            
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
        print("📱 Current user anonymous ID: \(Purchases.shared.appUserID)")
        
        isLoading = true
        purchaseError = nil
        
        do {
            print("🔄 Calling RevenueCat restorePurchases()...")
            let customerInfo = try await Purchases.shared.restorePurchases()
            print("✅ RevenueCat restore call completed")
            print("📊 Active entitlements: \(customerInfo.entitlements.active.keys)")
            await updateSubscriptionStatus(from: customerInfo)
            
            if isPremium {
                print("✅ Purchases restored successfully - Premium active")
            } else {
                print("ℹ️ No active subscriptions found during restore")
                purchaseError = "No previous purchases found to restore."
            }
            
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            print("🔍 Restore error details: \(error.localizedDescription)")
            
            // Handle specific RevenueCat/StoreKit errors
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("cancelled") || errorDescription.contains("canceled") {
                purchaseError = "Restore was cancelled. Please try again and complete Apple ID authentication when prompted.\n\nTip: If iOS capitalizes your email, manually correct it before signing in."
            } else if let revenueCatError = error as? ErrorCode {
                print("   RevenueCat error code: \(revenueCatError)")
                switch revenueCatError {
                case .purchaseCancelledError:
                    purchaseError = "Restore was cancelled. Please try again and complete Apple ID authentication when prompted."
                default:
                    purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
                }
            } else {
                purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
            }
            
            print("🏁 Restore purchases completed - isPremium: \(isPremium)")
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
            if let revenueCatError = error as? ErrorCode {
                print("   RevenueCat error code: \(revenueCatError)")
                print("   Error description: \(revenueCatError.localizedDescription)")
                
                // Check for common API key issues
                if revenueCatError.localizedDescription.contains("401") || 
                   revenueCatError.localizedDescription.lowercased().contains("unauthorized") {
                    print("   🔑 This appears to be an API key authentication issue")
                    print("   📝 Make sure the RevenueCat app is properly configured in the dashboard")
                    print("   📝 Verify that the bundle ID matches between Xcode and RevenueCat dashboard")
                }
            }
            // Don't set purchaseError for status checks - just log
        }
    }
    
    // Price string property - matches original interface
    var monthlyPriceString: String? {
        guard let monthlyPackage = currentOffering?.monthly else {
            return nil
        }
        return monthlyPackage.storeProduct.localizedPriceString
    }
    
    // MARK: - RevenueCat Customer Center Integration
    
    /// Show RevenueCat Customer Center for in-app subscription management
    /// This is a RevenueCat-specific feature that provides native subscription management UI
    func showCustomerCenter() {
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
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userID)
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to set user identity: \(error)")
            purchaseError = "Failed to link user account"
        }
    }
    
    /// Log out current user (useful for testing or account switching)
    func logOutUser() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("❌ Failed to log out user: \(error)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            
            if currentOffering?.monthly == nil {
                print("❌ No monthly subscription package found")
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
    }
    
    private func handleRevenueCatError(_ error: ErrorCode) {
        print("❌ RevenueCat error: \(error)")
        
        // Handle the most common cases - use string matching to avoid enum naming issues
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
            purchaseError = "Network error - please check your connection and try again"
        } else {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionService_RevenueCat: PurchasesDelegate {
    /// Called when RevenueCat receives updated customer information
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task {
            await updateSubscriptionStatus(from: customerInfo)
        }
    }
    
    /// Called when a promotional offer becomes available
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        // Auto-handle promotional purchases
        startPurchase { (transaction, customerInfo, error, cancelled) in
            Task {
                if let error = error {
                    print("❌ Promotional purchase failed: \(error)")
                    await MainActor.run {
                        self.purchaseError = "Promotional purchase failed"
                    }
                } else if !cancelled, let customerInfo = customerInfo {
                    await self.updateSubscriptionStatus(from: customerInfo)
                }
            }
        }
    }
}