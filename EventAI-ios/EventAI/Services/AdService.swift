import SwiftUI
import UIKit
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        
        // Set root view controller for better ad targeting
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            bannerView.rootViewController = window.rootViewController
        }
        
        bannerView.load(Request())
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // Update ad if needed - reload if necessary
    }
}

class AdService: ObservableObject {
    @Published var isAdLoaded = false
    @Published var isAdMobInitialized = false
    
    // Use test ad unit ID during development - replace with your real ad unit ID for production
    // Test Banner ID: ca-app-pub-3940256099942544/2934735716
    // Your Banner ID: Replace with your actual banner ad unit ID from AdMob console
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Using test ID for now
    
    func initializeAds() {
        print("🚀 Initializing AdMob SDK...")
        MobileAds.shared.start { status in
            DispatchQueue.main.async {
                self.isAdMobInitialized = true
                self.isAdLoaded = true
                print("✅ AdMob initialized successfully")
                print("📊 Initialization status: \(status.description)")
            }
        }
    }
    
    func loadBannerAd() -> AdBannerView {
        return AdBannerView(adUnitID: AdService.bannerAdUnitID)
    }
}