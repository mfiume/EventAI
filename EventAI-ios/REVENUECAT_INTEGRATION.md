# RevenueCat Integration Guide

## Overview
This document outlines the integration of RevenueCat for cross-platform subscription management in EventAI.

## Installation Steps

### 1. Add RevenueCat SDK via Xcode
1. Open EventAI.xcodeproj in Xcode
2. Select File → Add Package Dependencies
3. Enter URL: `https://github.com/RevenueCat/purchases-ios-spm.git`
4. Set version: "Up to next major" (5.0.0 < 6.0.0)
5. Add packages: `RevenueCat` and `RevenueCatUI`

### 2. Enable In-App Purchase Capability
1. Select EventAI target
2. Go to Signing & Capabilities
3. Click + and add "In-App Purchase" capability

### 3. Configure RevenueCat Dashboard
1. Create account at https://app.revenuecat.com
2. Create new app for iOS
3. Configure products:
   - Product ID: `eventai_premium_monthly`
   - Type: Auto-renewable subscription
   - Duration: 1 month

### 4. Implementation Strategy

#### Phase 1: Replace StoreKit with RevenueCat
- Update SubscriptionService to use RevenueCat SDK
- Maintain same interface for ContentView
- Add Customer Center for in-app management

#### Phase 2: Add Cross-Platform Support
- Configure web billing for future web app
- Implement user identity linking
- Set up webhooks for subscription events

#### Phase 3: Enhanced Features
- Add churn prevention in Customer Center
- Implement promotional offers
- Set up analytics and A/B testing

## Benefits Over Direct StoreKit

### 1. Simplified Management
- Single API for all subscription platforms
- Automatic receipt validation
- Built-in analytics and insights

### 2. Customer Experience
- Customer Center for in-app management
- Churn prevention with targeted offers
- Cross-platform subscription sharing

### 3. Business Intelligence
- Revenue analytics
- Subscription health metrics
- Customer lifecycle insights

### 4. Cross-Platform Ready
- iOS (Apple subscriptions)
- Android (Google subscriptions) 
- Web (Stripe/Paddle subscriptions)
- Unified user experience

## Cost Analysis

### Free Tier (0 - $2.5M revenue)
- RevenueCat: $0
- Only pay underlying payment processor fees
- Full feature access

### Growth Tier ($2.5M+ revenue)  
- RevenueCat: 1.2% of tracked revenue
- At $2.5M revenue: $30,000/year
- At this scale, easily justified by features/savings

## Next Steps
1. Install packages via Xcode
2. Create RevenueCat account and configure app
3. Update SubscriptionService implementation
4. Test subscription flows
5. Implement Customer Center
6. Plan web integration strategy