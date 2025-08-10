import Foundation

/// RevenueCat configuration constants
/// This centralizes all RevenueCat-related configuration to make setup easier
struct RevenueCatConfig {
    
    // MARK: - API Keys
    /// RevenueCat Public API Key - Replace with your actual key from RevenueCat dashboard
    /// Get this from: RevenueCat Dashboard → Your App → API Keys → Public API Key
    static let publicAPIKey = "appl_YOUR_REVENUECAT_PUBLIC_KEY_HERE"
    
    // MARK: - Product Identifiers
    /// The product ID for the monthly subscription - must match App Store Connect exactly
    static let monthlyProductID = "eventai_premium_monthly"
    
    // MARK: - Entitlement Identifiers  
    /// The entitlement identifier configured in RevenueCat dashboard
    static let premiumEntitlementID = "premium"
    
    // MARK: - Offering Identifiers
    /// The default offering identifier - typically "default" unless you have multiple offerings
    static let defaultOfferingID = "default"
    
    // MARK: - Configuration Validation
    /// Validates that all required configuration is set up properly
    static func validateConfiguration() -> [String] {
        var errors: [String] = []
        
        // Check API key is set
        if publicAPIKey.contains("YOUR_REVENUECAT_PUBLIC_KEY_HERE") {
            errors.append("RevenueCat Public API Key not configured. Please update RevenueCatConfig.publicAPIKey with your actual key from RevenueCat dashboard.")
        }
        
        // Check API key format (RevenueCat public keys start with platform prefix)
        if !publicAPIKey.hasPrefix("appl_") && !publicAPIKey.contains("YOUR_REVENUECAT_PUBLIC_KEY_HERE") {
            errors.append("RevenueCat Public API Key should start with 'appl_' for iOS apps.")
        }
        
        // Validate product ID format
        if monthlyProductID.isEmpty {
            errors.append("Monthly product ID cannot be empty.")
        }
        
        // Validate entitlement ID
        if premiumEntitlementID.isEmpty {
            errors.append("Premium entitlement ID cannot be empty.")
        }
        
        return errors
    }
    
    // MARK: - Debug Configuration
    #if DEBUG
    /// Enable verbose logging in debug builds
    static let enableDebugLogging = true
    #else
    /// Disable verbose logging in release builds  
    static let enableDebugLogging = false
    #endif
}

// MARK: - Setup Instructions
/*
 
 SETUP INSTRUCTIONS:
 
 1. Get your RevenueCat Public API Key:
    - Go to https://app.revenuecat.com
    - Select your app
    - Go to API Keys section
    - Copy the "Public API Key" (starts with "appl_")
    
 2. Update the publicAPIKey above with your actual key
 
 3. Verify product IDs match your App Store Connect setup:
    - Monthly subscription: "eventai_premium_monthly"
    
 4. Configure entitlements in RevenueCat dashboard:
    - Create entitlement with identifier: "premium"
    - Attach your subscription products to this entitlement
    
 5. Create offerings in RevenueCat dashboard:
    - Default offering with identifier: "default"  
    - Add monthly package to the offering
    
 6. Test the configuration:
    - Build and run the app
    - Check console for any validation errors
    - Use the SubscriptionTestView to test purchases
 
 */