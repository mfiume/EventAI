#!/usr/bin/env swift

import Foundation
import StoreKit

// Simple StoreKit test
print("🔧 Testing StoreKit Configuration...")

let productID = "eventai_premium_monthly"
print("📦 Looking for product ID: \(productID)")

Task {
    do {
        let products = try await Product.products(for: [productID])
        print("✅ Found \(products.count) products:")
        
        for product in products {
            print("   - ID: \(product.id)")
            print("   - Name: \(product.displayName)")
            print("   - Price: \(product.displayPrice)")
            print("   - Type: \(product.type)")
        }
        
        if products.isEmpty {
            print("❌ No products found!")
            print("🔍 Possible issues:")
            print("   - StoreKit configuration not loaded")
            print("   - Product ID mismatch")
            print("   - StoreKit file not properly configured")
        }
    } catch {
        print("❌ Error loading products: \(error)")
    }
    
    exit(0)
}

// Keep the script running
RunLoop.main.run()