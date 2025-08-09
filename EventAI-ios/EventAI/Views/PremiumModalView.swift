import SwiftUI
import StoreKit

struct PremiumModalView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var localizedPrice: String = "$4.99/month"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.5), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)

                // Darker overlay for better text readability
                Color.black.opacity(0.4)
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
                    .padding(.top, 20)

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
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Description
                        Text("Get unlimited calendar events, remove ads, and add photos to provide context for your events.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)

                        // Features
                        VStack(spacing: 12) {
                            FeatureRow(icon: "checkmark.circle.fill", text: "20 conversions per day (vs 3)")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Ad-free experience")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Photo analysis for events")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Priority processing")
                        }
                    }
                    .padding(.horizontal, 20) // Screen edge padding for all content

                    Spacer()

                    // Upgrade button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await subscriptionService.purchaseSubscription()
                                if subscriptionService.isPremium {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if subscriptionService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                Text(subscriptionService.isLoading ? "Processing..." : "Upgrade to Premium")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.yellow.opacity(subscriptionService.isLoading ? 0.6 : 1.0))
                            )
                        }
                        .disabled(subscriptionService.isLoading)

                        Text("\(localizedPrice) • Cancel anytime")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20) // Screen edge padding for buttons
                    .padding(.bottom, 40)
                } // Close main content VStack
                
                // Error message overlay
                if let errorMessage = subscriptionService.purchaseError {
                    VStack {
                        Spacer()
                            .frame(height: 140) // Space for close button area
                        
                        // Error banner
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
                            Button(action: { 
                                // Clear error - we'd need to add this to SubscriptionService
                            }) {
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
        .onAppear {
            Task {
                await loadLocalizedPrice()
            }
        }
    }

    private func loadLocalizedPrice() async {
        await MainActor.run {
            localizedPrice = subscriptionService.monthlyPriceString
        }
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