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
    @Published var isInterstitialLoaded = false
    
    private var interstitialAd: InterstitialAd?
    
    // AdMob ad unit IDs - Your real production IDs
    static let bannerAdUnitID = "ca-app-pub-5748015623915247/9049521670" // Your banner ad unit ID
    static let interstitialAdUnitID = "ca-app-pub-5748015623915247/7605444032" // Your interstitial ad unit ID
    
    func initializeAds() {
        print("🚀 Initializing AdMob SDK...")
        MobileAds.shared.start { status in
            DispatchQueue.main.async {
                self.isAdMobInitialized = true
                self.isAdLoaded = true
                print("✅ AdMob initialized successfully")
                print("📊 Initialization status: \(status.description)")
                // Load interstitial ad after initialization
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadBannerAd() -> AdBannerView {
        return AdBannerView(adUnitID: AdService.bannerAdUnitID)
    }
    
    func loadInterstitialAd() {
        print("🚀 Loading interstitial ad...")
        let request = Request()
        
        InterstitialAd.load(with: AdService.interstitialAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                    self?.isInterstitialLoaded = false
                    return
                }
                
                self?.interstitialAd = ad
                self?.isInterstitialLoaded = true
                print("✅ Interstitial ad loaded successfully")
            }
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let interstitialAd = interstitialAd, isInterstitialLoaded else {
            print("⚠️ Interstitial ad not ready, proceeding without ad")
            completion()
            return
        }
        
        print("📺 Showing interstitial ad...")
        interstitialAd.present(from: viewController)
        
        // Reset the ad and load a new one for next time
        self.interstitialAd = nil
        self.isInterstitialLoaded = false
        loadInterstitialAd()
        
        // Call completion after a short delay to allow ad to be shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }
}