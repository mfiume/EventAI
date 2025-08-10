# RevenueCat Setup Guide for EventAI

## Step 1: Install RevenueCat SDK

### Option A: Using Xcode (Recommended)
1. Open `EventAI.xcodeproj` in Xcode
2. Select File → Add Package Dependencies
3. Enter URL: `https://github.com/RevenueCat/purchases-ios-spm.git`
4. Set dependency rule: "Up to next major" (5.0.0 < 6.0.0)
5. Select packages: `RevenueCat` and `RevenueCatUI`
6. Click "Add Package"

### Option B: Manual Package.swift (if using SPM directly)
```swift
dependencies: [
    .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0")
]
```

## Step 2: Enable In-App Purchase Capability
1. Select EventAI target in Xcode
2. Go to Signing & Capabilities tab
3. Click + button and add "In-App Purchase" capability
4. Ensure your Apple Developer account has proper agreements signed

## Step 3: Create RevenueCat Account & Configure App

### 3.1 Sign up for RevenueCat
1. Go to https://app.revenuecat.com
2. Sign up with your email
3. Choose "Free" plan (free until $2.5M revenue)

### 3.2 Create iOS App
1. Click "Add App" in RevenueCat dashboard
2. Choose iOS platform
3. Enter app details:
   - **App Name**: EventAI
   - **Bundle ID**: `com.yourcompany.eventai` (match your Xcode bundle ID)
   - **App Store Connect App ID**: Your App Store Connect app ID

### 3.3 Get API Keys
1. In RevenueCat dashboard, go to App Settings
2. Copy the "Public API Key" for iOS
3. **IMPORTANT**: This key will replace `YOUR_REVENUECAT_API_KEY` in our code

## Step 4: Configure Products & Entitlements

### 4.1 Create Entitlement
1. Go to "Entitlements" tab in RevenueCat
2. Click "New Entitlement"
3. Create entitlement:
   - **Identifier**: `premium`
   - **Display Name**: Premium Features

### 4.2 Create Products
1. Go to "Products" tab
2. Click "New Product"
3. Configure monthly subscription:
   - **Product ID**: `eventai_premium_monthly` (must match App Store Connect)
   - **Type**: Subscription
   - **Display Name**: EventAI Premium Monthly
   
### 4.3 Create Offering
1. Go to "Offerings" tab  
2. Click "New Offering"
3. Create offering:
   - **Identifier**: `default`
   - **Display Name**: Default Offering
4. Add monthly package:
   - **Product**: eventai_premium_monthly
   - **Package Type**: Monthly
   - **Identifier**: `monthly`

### 4.4 Link Products to Entitlements
1. In the "Products" tab, select your monthly product
2. In "Entitlements" section, attach the `premium` entitlement

## Step 5: Update Code Configuration

### 5.1 Add API Key
Replace the placeholder in `SubscriptionService_RevenueCat.swift`:

```swift
private let apiKey = "your_actual_revenuecat_public_api_key_here"
```

### 5.2 Add RevenueCat Imports
Add to any files using RevenueCat:
```swift
import RevenueCat
import RevenueCatUI  // For Customer Center
```

## Step 6: Test Setup

### 6.1 Build and Run
1. Build the app with the RevenueCat SDK
2. Check console for RevenueCat initialization logs
3. Navigate to the "🧪 Test" button (DEBUG builds only)

### 6.2 Test Subscription Flow
1. Open SubscriptionTestView
2. Switch to "RevenueCat" implementation
3. Try the "Purchase via RevenueCat" button
4. Verify the subscription status updates

### 6.3 Test Customer Center
1. In the test view, try "Customer Center" button
2. Should show native subscription management UI
3. Test cancellation/reactivation flows

## Step 7: App Store Connect Configuration

### 7.1 Create Subscription in App Store Connect
1. Go to App Store Connect
2. Select your app → Features → In-App Purchases
3. Create new subscription:
   - **Product ID**: `eventai_premium_monthly` (exact match)
   - **Reference Name**: EventAI Premium Monthly
   - **Duration**: 1 Month
   - **Price**: $4.99 (or your preferred price)

### 7.2 Review Information
- **Display Name**: EventAI Premium
- **Description**: Get unlimited calendar events, remove ads, and unlock priority processing for your events.

## Step 8: Testing & Debugging

### 8.1 RevenueCat Debug Logs
Check Xcode console for RevenueCat logs:
```
🔧 Initializing RevenueCat service...
✅ RevenueCat configured with API key
💰 Monthly subscription loaded: EventAI Premium - $4.99
```

### 8.2 Common Issues

**Products not loading:**
- Verify App Store Connect product is approved
- Check product ID matches exactly
- Ensure offerings are published in RevenueCat

**Purchase fails:**
- Check sandbox user is signed in (Settings → App Store → Sandbox Account)  
- Verify In-App Purchase capability is enabled
- Check RevenueCat logs for specific error codes

**Customer Center not showing:**
- Requires iOS 15+
- Check RevenueCatUI is properly imported
- Verify app has active subscription to test with

## Step 9: Production Checklist

Before releasing:
- [ ] Replace DEBUG API key with production key
- [ ] Set `Purchases.logLevel = .warn` (remove .debug)
- [ ] Test on physical device with sandbox account
- [ ] Verify subscription restoration works
- [ ] Test Customer Center on iOS 15+ devices
- [ ] Ensure all RevenueCat products are published

## Benefits of This Setup

### For Users:
- Native subscription management (Customer Center)
- Cross-platform subscription sharing (future web app)
- Better cancellation/reactivation experience

### For Development:
- Unified subscription API across platforms
- Automatic receipt validation
- Rich analytics and insights
- A/B testing capabilities

### For Business:
- Free until $2.5M revenue
- Only 1.2% fee after that (vs 30¢ per $0.99 transaction)
- Built-in churn prevention tools
- Customer support automation

## Next Steps

After this setup:
1. Test both StoreKit and RevenueCat implementations
2. Measure performance and user experience differences
3. Plan migration to RevenueCat as primary implementation
4. Design web app integration strategy
5. Set up cross-platform user identity linking