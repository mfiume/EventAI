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

class AdService: NSObject, ObservableObject {
    @Published var isAdLoaded = false
    @Published var isAdMobInitialized = false
    @Published var isInterstitialLoaded = false
    
    private var interstitialAd: InterstitialAd?
    private var adCompletionHandler: (() -> Void)?
    
    // AdMob ad unit IDs - Use test IDs for development, production IDs for release
    #if DEBUG
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Google test banner ad unit
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test interstitial ad unit
    #else
    static let bannerAdUnitID = "ca-app-pub-5748015623915247/9049521670" // Your banner ad unit ID
    static let interstitialAdUnitID = "ca-app-pub-5748015623915247/7605444032" // Your interstitial ad unit ID
    #endif
    
    func initializeAds() {
        MobileAds.shared.start { status in
            DispatchQueue.main.async {
                self.isAdMobInitialized = true
                self.isAdLoaded = true
                
                // Load interstitial ad after initialization
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadBannerAd() -> AdBannerView {
        return AdBannerView(adUnitID: AdService.bannerAdUnitID)
    }
    
    func loadInterstitialAd() {
        let request = Request()
        
        InterstitialAd.load(with: AdService.interstitialAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                    self?.isInterstitialLoaded = false
                    return
                }
                
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                self?.isInterstitialLoaded = true
            }
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let interstitialAd = interstitialAd, isInterstitialLoaded else {
            completion()
            return
        }
        
        // Store completion handler to call when ad is actually dismissed
        self.adCompletionHandler = completion
        
        // Present the ad - completion will be called by delegate methods
        interstitialAd.present(from: viewController)
        
        // Reset the ad and load a new one for next time
        self.interstitialAd = nil
        self.isInterstitialLoaded = false
        loadInterstitialAd()
    }
}

// MARK: - FullScreenContentDelegate
extension AdService: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Ad will present
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Interstitial ad failed to present: \(error.localizedDescription)")
        // Call completion if ad fails to show
        adCompletionHandler?()
        adCompletionHandler = nil
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Call completion only when user actually dismisses the ad
        adCompletionHandler?()
        adCompletionHandler = nil
    }
}