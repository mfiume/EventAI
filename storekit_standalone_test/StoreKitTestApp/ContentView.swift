import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var status = "Ready to test"
    @State private var detailsVisible = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🧪 StoreKit Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text(status)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Test Product Loading") {
                Task {
                    await testProductLoading()
                }
            }
            .buttonStyle(.borderedProminent)
            
            if !products.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("✅ Products Found: \(products.count)")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    ForEach(products, id: \.id) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("ID: \(product.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Price: \(product.displayPrice)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            
            Button("Show Technical Details") {
                detailsVisible.toggle()
            }
            .font(.caption)
            
            if detailsVisible {
                VStack(alignment: .leading, spacing: 5) {
                    Text("🔧 Technical Info:")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("• Bundle ID: com.test.storekittest")
                        .font(.caption2)
                    Text("• Team ID: D8R2VUC2Y3")
                        .font(.caption2)
                    Text("• StoreKit config: EventAI.storekit")
                        .font(.caption2)
                    Text("• Testing mode: Local configuration")
                        .font(.caption2)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    func testProductLoading() async {
        status = "🔄 Loading products..."
        
        do {
            print("📞 Calling Product.products(for:)")
            let productIDs = ["eventai_premium_monthly"]
            let loadedProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                products = loadedProducts
                
                if loadedProducts.isEmpty {
                    status = "❌ No products found\n\nThis suggests StoreKit configuration is not being loaded properly in the test environment."
                } else {
                    status = "✅ Found \(loadedProducts.count) product(s)!\n\nStoreKit configuration is working correctly."
                    
                    for product in loadedProducts {
                        print("✅ Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                status = "❌ Error: \(error.localizedDescription)\n\nThis indicates a StoreKit configuration or environment issue."
            }
            print("❌ StoreKit Error: \(error)")
        }
    }
}
