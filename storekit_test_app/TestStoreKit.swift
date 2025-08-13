#!/usr/bin/env swift

import Foundation
import StoreKit

print("🧪 Testing StoreKit Configuration Loading...")
print("=" * 50)

// Test 1: Basic StoreKit functionality
print("Test 1: Basic StoreKit API availability")
do {
    let productIDs = ["eventai_premium_monthly", "com.test.product"]
    print("📦 Testing with product IDs: \(productIDs)")
    
    let task = Task {
        do {
            let products = try await Product.products(for: productIDs)
            print("✅ StoreKit API call successful")
            print("📊 Found \(products.count) products")
            
            if products.isEmpty {
                print("⚠️  No products found - this is expected without proper configuration")
            } else {
                for product in products {
                    print("   - \(product.id): \(product.displayName) (\(product.displayPrice))")
                }
            }
        } catch {
            print("❌ StoreKit API error: \(error)")
        }
    }
    
    // Wait for completion
    _ = await task.value
    
} catch {
    print("❌ Setup error: \(error)")
}

print("\n" + "=" * 50)
print("🏁 Test completed")