import SwiftUI
import StoreKit

struct PremiumModalView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRestoreInfo = false
    @State private var localizedPrice: String? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Use dark gradient background similar to BlastThePast
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.6), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)

                // Darker overlay for better text readability
                Color.black.opacity(0.7)
                    .ignoresSafeArea(.all)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width/2, y: geometry.size.height/2)

                // Close button positioned absolutely at top-right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20) // 20px from top

                    Spacer()
                }

                // Main content with proper screen edge padding
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 100) // Space for close button

                    Spacer()

                    // Premium content with screen edge padding
                    VStack(spacing: 24) {
                        // Title
                        Text("Upgrade to Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        // Unlock text
                        Text("Unlock EventAI Premium")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black, radius: 1, x: 0, y: 1)

                        // Large app icon
                        Image("LaunchImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Description (four lines, ellipsized)
                        Text("Get more daily conversions and unlock priority processing for your events.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)

                        // Features
                        VStack(spacing: 12) {
                            FeatureRow(icon: "checkmark.circle.fill", text: "20 conversions per day (vs 3)")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Ad-free experience")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Priority processing")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Support development")
                        }
                    }
                    .padding(.horizontal, 20) // Screen edge padding for all content

                    Spacer()

                    // Upgrade button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await purchasePremium()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                Text(isLoading ? "Processing..." : "Upgrade to Premium")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.yellow.opacity(isLoading ? 0.6 : 1.0))
                            )
                        }
                        .disabled(isLoading)

                        // Subscription details (Apple requirement)
                        VStack(spacing: 8) {
                            if let price = localizedPrice {
                                Text("EventAI Premium: \(price)/month")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            } else {
                                Text("EventAI Premium: Monthly Subscription")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Auto-renewable • Cancel anytime")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        // Legal links (Apple requirement)
                        HStack(spacing: 20) {
                            Button("Terms of Use") {
                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            
                            Button("Privacy Policy") {
                                if let url = URL(string: "https://leveluplife.app/eventai/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                        
                        Button("Restore Purchases") {
                            showRestoreInfo = true
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 20) // Screen edge padding for buttons
                    .padding(.bottom, 40)
                } // Close main content VStack
                
                // Error message overlay - positioned above title where there's more room
                if let errorMessage = errorMessage {
                    VStack {
                        Spacer()
                            .frame(height: 140) // Space for close button area
                        
                        // Error banner matching ChatView style
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Button(action: { self.errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreInfo) {
            Button("Continue") {
                Task {
                    await restorePurchases()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("iOS will ask for your Apple ID. If it capitalizes your email address, manually correct it before signing in.\n\nExample: Change 'John@gmail.com' back to 'john@gmail.com'")
        }
        .onAppear {
            Task {
                await loadLocalizedPrice()
            }
        }
    }

    private func loadLocalizedPrice() async {
        // Use the subscription service's price
        await MainActor.run {
            localizedPrice = subscriptionService.monthlyPriceString
        }
    }

    private func purchasePremium() async {
        print("🎯 PremiumModal: Starting purchase process...")
        isLoading = true
        errorMessage = nil

        // Use the subscription service for the purchase
        await subscriptionService.purchaseSubscription()
        
        print("🎯 PremiumModal: Purchase completed - isPremium: \(subscriptionService.isPremium), error: \(subscriptionService.purchaseError ?? "none")")
        
        // Check results from subscription service
        if let error = subscriptionService.purchaseError {
            errorMessage = error
            print("🎯 PremiumModal: Showing error: \(error)")
        } else if subscriptionService.isPremium {
            // Purchase successful and confirmed
            print("🎯 PremiumModal: Purchase successful, dismissing modal")
            dismiss()
        } else {
            // Handle edge cases - user may have cancelled or other scenarios
            print("🎯 PremiumModal: Purchase completed but status unclear")
            
            // Check if it was just a cancellation (no error set)
            if subscriptionService.purchaseError == nil {
                // User likely cancelled, don't show error
                print("🎯 PremiumModal: User likely cancelled, no error message")
            } else {
                // Show helpful message for edge cases
                errorMessage = "Purchase completed! If premium features don't appear immediately, please restart the app or use 'Restore Purchases'."
                
                // Auto-dismiss after showing message
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismiss()
                }
            }
        }

        isLoading = false
    }

    private func restorePurchases() async {
        print("🎯 PremiumModal: Starting restore purchases...")
        isLoading = true
        errorMessage = nil

        // Use the subscription service to restore purchases
        await subscriptionService.restorePurchases()
        
        print("🎯 PremiumModal: Restore completed - isPremium: \(subscriptionService.isPremium), error: \(subscriptionService.purchaseError ?? "none")")
        
        // Check results from subscription service
        if subscriptionService.isPremium {
            // Restore successful
            errorMessage = "Purchases restored successfully!"
            print("🎯 PremiumModal: Restore successful, dismissing modal")
            
            // Auto-dismiss after showing success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } else if let error = subscriptionService.purchaseError {
            errorMessage = error
            print("🎯 PremiumModal: Restore failed with error: \(error)")
        } else {
            errorMessage = "No previous purchases found to restore."
            print("🎯 PremiumModal: No purchases found to restore")
        }

        isLoading = false
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()
        }
    }
}

#Preview {
    PremiumModalView(subscriptionService: SubscriptionService())
        .preferredColorScheme(.dark)
}