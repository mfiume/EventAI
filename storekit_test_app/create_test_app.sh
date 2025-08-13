#!/bin/bash

echo "🧪 Creating minimal StoreKit test app..."

# Create the test app directory structure
mkdir -p StoreKitTestApp/StoreKitTestApp

# Create App.swift
cat > StoreKitTestApp/StoreKitTestApp/App.swift << 'EOF'
import SwiftUI

@main
struct StoreKitTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

# Create ContentView.swift
cat > StoreKitTestApp/StoreKitTestApp/ContentView.swift << 'EOF'
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
EOF

# Create Info.plist
cat > StoreKitTestApp/StoreKitTestApp/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>StoreKit Test</string>
    <key>CFBundleIdentifier</key>
    <string>com.test.storekittest</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF

echo "✅ Minimal test app created!"
echo "📁 Location: StoreKitTestApp/"
echo "📋 Next steps:"
echo "   1. Open in Xcode"
echo "   2. Add StoreKit configuration file"
echo "   3. Configure scheme for StoreKit testing"
echo "   4. Run in simulator"