import Foundation

/// RevenueCat configuration constants
/// This centralizes all RevenueCat-related configuration to make setup easier
struct RevenueCatConfig {
    
    // MARK: - API Keys
    /// RevenueCat Public API Key - Loaded from build configuration (Config.xcconfig)
    static let publicAPIKey: String = {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String,
              !apiKey.isEmpty else {
            fatalError("RevenueCat API key not found in build configuration. Please add REVENUECAT_API_KEY to Config.xcconfig and configure build settings.")
        }
        return apiKey
    }()
    
    // MARK: - Product Identifiers
    /// The product ID for the monthly subscription - must match App Store Connect exactly
    static let monthlyProductID = "eventai_premium_monthly"
    
    // MARK: - Entitlement Identifiers  
    /// The entitlement identifier configured in RevenueCat dashboard
    static let premiumEntitlementID = "premium"
    
    // MARK: - Offering Identifiers
    /// The default offering identifier - typically "default" unless you have multiple offerings
    static let defaultOfferingID = "default"
    
    // MARK: - Vendor Configuration
    /// Apple Developer Vendor Number - used for App Store Connect identification
    static let vendorNumber = "93609904"
    
    // MARK: - Configuration Validation
    /// Validates that all required configuration is set up properly
    static func validateConfiguration() -> [String] {
        var errors: [String] = []
        
        // Check API key format (RevenueCat public keys start with platform prefix)
        if !publicAPIKey.hasPrefix("appl_") {
            errors.append("RevenueCat Public API Key should start with 'appl_' for iOS apps. Current key: \(publicAPIKey.prefix(8))...")
        }
        
        // Check API key length (should be reasonably long)
        if publicAPIKey.count < 20 {
            errors.append("RevenueCat API Key seems too short. Expected length > 20 characters.")
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
 
 1. Create Config.xcconfig from template:
    - Copy Config.example.xcconfig to Config.xcconfig
    - Config.xcconfig is gitignored for security
    
 2. Get your RevenueCat Public API Key:
    - Go to https://app.revenuecat.com
    - Select your app
    - Go to API Keys section
    - Copy the "Public API Key" (starts with "appl_")
    
 3. Update Config.xcconfig with your actual key:
    - Replace "appl_your_revenuecat_api_key_here" with your real key
    
 4. Configure build settings (one-time setup):
    - In Xcode, select EventAI project
    - Go to Build Settings tab
    - Search for "Based on Configuration File"
    - Set Debug and Release to use Config.xcconfig
    
 4. Verify product IDs match your App Store Connect setup:
    - Monthly subscription: "eventai_premium_monthly"
    
 5. Configure entitlements in RevenueCat dashboard:
    - Create entitlement with identifier: "premium"
    - Attach your subscription products to this entitlement
    
 6. Create offerings in RevenueCat dashboard:
    - Default offering with identifier: "default"  
    - Add monthly package to the offering
    
 7. Test the configuration:
    - Build and run the app
    - Check console for any validation errors
    - Use the SubscriptionTestView to test purchases
 
 */