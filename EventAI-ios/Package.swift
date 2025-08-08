// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EventAI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "EventAI",
            targets: ["EventAI"]
        ),
    ],
    dependencies: [
        // Google Mobile Ads SDK
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "11.0.0")
    ],
    targets: [
        .target(
            name: "EventAI",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]
        ),
    ]
)