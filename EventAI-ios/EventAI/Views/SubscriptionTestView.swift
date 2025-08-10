import SwiftUI

/// Test view to compare StoreKit vs RevenueCat subscription implementations
struct SubscriptionTestView: View {
    @StateObject private var storeKitService = SubscriptionService()
    @StateObject private var revenueCatService = SubscriptionService_RevenueCat()
    @State private var selectedImplementation = "StoreKit"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Implementation Selector
                Picker("Implementation", selection: $selectedImplementation) {
                    Text("StoreKit Direct").tag("StoreKit")
                    Text("RevenueCat").tag("RevenueCat")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Status Display
                statusSection
                
                Spacer()
                
                // Action Buttons
                actionButtons
                
                Spacer()
            }
            .navigationTitle("Subscription Test")
            .padding()
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 16) {
            Text("Current Status")
                .font(.headline)
            
            if selectedImplementation == "StoreKit" {
                SubscriptionStatusCard(
                    title: "StoreKit Direct",
                    isPremium: storeKitService.isPremium,
                    status: storeKitService.subscriptionStatus,
                    expiryDate: storeKitService.expiryDate,
                    priceString: storeKitService.monthlyPriceString,
                    isLoading: storeKitService.isLoading,
                    error: storeKitService.purchaseError
                )
            } else {
                SubscriptionStatusCard(
                    title: "RevenueCat",
                    isPremium: revenueCatService.isPremium,
                    status: revenueCatService.subscriptionStatus,
                    expiryDate: revenueCatService.expiryDate,
                    priceString: revenueCatService.monthlyPriceString,
                    isLoading: revenueCatService.isLoading,
                    error: revenueCatService.purchaseError
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if selectedImplementation == "StoreKit" {
                Button("Purchase via StoreKit") {
                    Task { await storeKitService.purchaseSubscription() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(storeKitService.isLoading)
                
                Button("Restore Purchases (StoreKit)") {
                    Task { await storeKitService.restorePurchases() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(storeKitService.isLoading)
                
                Button("Check Status (StoreKit)") {
                    Task { await storeKitService.checkSubscriptionStatus() }
                }
                .buttonStyle(SecondaryButtonStyle())
                
            } else {
                Button("Purchase via RevenueCat") {
                    Task { await revenueCatService.purchaseSubscription() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(revenueCatService.isLoading)
                
                Button("Restore Purchases (RevenueCat)") {
                    Task { await revenueCatService.restorePurchases() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(revenueCatService.isLoading)
                
                Button("Customer Center") {
                    revenueCatService.showCustomerCenter()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Check Status (RevenueCat)") {
                    Task { await revenueCatService.checkSubscriptionStatus() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

struct SubscriptionStatusCard: View {
    let title: String
    let isPremium: Bool
    let status: String
    let expiryDate: Date?
    let priceString: String
    let isLoading: Bool
    let error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("Status:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(status)
                    .fontWeight(.medium)
                    .foregroundColor(isPremium ? .green : .primary)
            }
            
            HStack {
                Text("Premium:")
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: isPremium ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(isPremium ? .green : .red)
            }
            
            HStack {
                Text("Price:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(priceString + "/month")
                    .fontWeight(.medium)
            }
            
            if let expiryDate = expiryDate {
                HStack {
                    Text("Expires:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(DateFormatter.shortDateTime.string(from: expiryDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if let error = error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SubscriptionTestView()
}