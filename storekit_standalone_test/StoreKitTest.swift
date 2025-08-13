import Foundation
import StoreKit

struct StoreKitTest {
    static func main() async {
        print("🧪 StoreKit Standalone Test")
        print("================================")
        
        let productID = "eventai_premium_monthly"
        print("📦 Testing product ID: \(productID)")
        
        do {
            print("🔄 Calling Product.products(for:)...")
            let products = try await Product.products(for: [productID])
            
            print("✅ API call successful!")
            print("📊 Results:")
            print("   - Products found: \(products.count)")
            
            if products.isEmpty {
                print("❌ No products returned")
                print("🔍 This could mean:")
                print("   - StoreKit configuration not loaded")
                print("   - Product ID doesn't exist in config")
                print("   - StoreKit testing not enabled")
                print("   - Running outside simulator environment")
            } else {
                for (index, product) in products.enumerated() {
                    print("   Product \(index + 1):")
                    print("     - ID: \(product.id)")
                    print("     - Name: \(product.displayName)")
                    print("     - Price: \(product.displayPrice)")
                    print("     - Type: \(product.type)")
                    if let subscription = product.subscription {
                        print("     - Subscription Period: \(subscription.subscriptionPeriod)")
                    }
                }
            }
            
        } catch {
            print("❌ Error occurred: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
        }
        
        print("================================")
        print("🏁 Test completed")
    }
}

await StoreKitTest.main()