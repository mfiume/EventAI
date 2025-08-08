import SwiftUI
import UIKit

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    
    func makeUIView(context: Context) -> UIView {
        let bannerView = UIView()
        bannerView.backgroundColor = UIColor.systemGray6
        
        let label = UILabel()
        label.text = "Ad Space - Ready for AdMob Integration"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        
        bannerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor)
        ])
        
        return bannerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update ad if needed
    }
}

class AdService: ObservableObject {
    @Published var isAdLoaded = false
    
    // Test Ad Unit ID - Replace with real Ad Unit ID from Google AdMob
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Test ID
    
    func initializeAds() {
        // Initialize Google Mobile Ads SDK here
        print("AdMob SDK would be initialized here")
        isAdLoaded = true
    }
    
    func loadBannerAd() -> AdBannerView {
        return AdBannerView(adUnitID: AdService.bannerAdUnitID)
    }
}