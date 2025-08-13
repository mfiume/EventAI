import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var status = "Ready to test"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("StoreKit Test App")
                .font(.title)
            
            Text(status)
                .foregroundColor(.secondary)
            
            Button("Test Product Loading") {
                Task {
                    await testProductLoading()
                }
            }
            .buttonStyle(.borderedProminent)
            
            if !products.isEmpty {
                VStack(alignment: .leading) {
                    Text("Products Found:")
                        .font(.headline)
                    
                    ForEach(products, id: \.id) { product in
                        VStack(alignment: .leading) {
                            Text(product.displayName)
                                .font(.subheadline)
                            Text("ID: \(product.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Price: \(product.displayPrice)")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
    
    func testProductLoading() async {
        status = "Loading products..."
        
        do {
            let productIDs = ["eventai_premium_monthly"]
            let loadedProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                products = loadedProducts
                status = "Found \(loadedProducts.count) products"
                
                if loadedProducts.isEmpty {
                    status = "No products found - check StoreKit configuration"
                }
            }
            
        } catch {
            await MainActor.run {
                status = "Error: \(error.localizedDescription)"
            }
        }
    }
}
