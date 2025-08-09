# EventAI App Store Connect Configuration Guide

This guide provides step-by-step instructions for configuring EventAI's freemium subscription model in App Store Connect.

## 🎯 Freemium Model Summary

**Free Tier:**
- 3 calendar event conversions per day
- Full-screen ads with 5-second minimum display
- Banner ads in event preview
- No photo upload support

**Premium Tier ($4.99/month USD):**
- 20 calendar event conversions per day
- No advertising
- Photo upload support for event context
- Auto-renewable monthly subscription

---

## 📋 Prerequisites

Before starting this configuration:

1. ✅ EventAI iOS app built successfully with StoreKit 2 integration
2. ✅ Backend API deployed with subscription validation endpoints
3. ✅ Apple Developer Program membership (required for subscriptions)
4. ✅ App Store Connect access with Admin role
5. ✅ Tax and banking information configured in App Store Connect

---

## 🔧 Step 1: Create App Record in App Store Connect

### 1.1 Basic App Information
1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Fill out the form:
   - **Platform:** iOS
   - **Name:** EventAI
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** `com.leveluplife.eventai` (must match your Xcode project)
   - **SKU:** `eventai-ios-app` (unique identifier for internal tracking)

### 1.2 App Information Section
Navigate to **App Information** and configure:

**General Information:**
- **Subtitle:** "AI-Powered Calendar Events"
- **Categories:** 
  - Primary: Productivity
  - Secondary: Business
- **Content Rights:** Check if you own all content

**App Review Information:**
- **Sign-In Required:** No
- **Reviewed on Device:** iPhone
- **Age Rating:** 4+

---

## 💰 Step 2: Configure In-App Purchases & Subscriptions

### 2.1 Create Subscription Group
1. Navigate to **Features** → **In-App Purchases and Subscriptions**
2. Click **"Manage"** next to **"Subscription Groups"**
3. Click **"Create Subscription Group"**
4. Configure:
   - **Reference Name:** EventAI Premium Subscriptions
   - **App Store Display Name:** EventAI Premium

### 2.2 Create Monthly Subscription
1. In your subscription group, click **"Create Subscription"**
2. Fill out the form:

**General Information:**
- **Reference Name:** EventAI Premium Monthly
- **Product ID:** `eventai_premium_monthly` (CRITICAL: must match SubscriptionService.swift)
- **Subscription Duration:** 1 Month
- **Subscription Group:** EventAI Premium Subscriptions

**Subscription Prices:**
- **Price:** $4.99 USD
- **Availability:** All territories (or customize as needed)

**Review Information:**
- **Subscription Display Name:** EventAI Premium
- **Description:** Unlock unlimited calendar events, remove ads, and add photos to your events.

**App Store Localization:**
- **Display Name:** EventAI Premium
- **Description:** 
```
Get the most out of EventAI with Premium:

✨ Create up to 20 calendar events per day
🚫 Ad-free experience  
📸 Add photos to provide context for events
⚡ Priority processing for faster results

Perfect for busy professionals, event planners, and anyone who needs to manage multiple calendar events efficiently.

Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your Account Settings.
```

### 2.3 Subscription Features Configuration
**Promotional Features:**
- **Introductory Price:** Optional - consider 3-day free trial
- **Promotional Offers:** Can be configured later for win-back campaigns

**Family Sharing:** Enabled (allows family members to share the subscription)

### 2.4 Review Information for Subscription
**Screenshot Requirements:**
You'll need to provide screenshots showing:
- Free vs Premium comparison
- Photo upload feature in action
- Ad-free interface
- Usage limits explanation

---

## 📱 Step 3: App Store Listing Configuration

### 3.1 Version Information
Navigate to **1.0 Prepare for Submission**:

**App Information:**
- **Name:** EventAI
- **Subtitle:** AI-Powered Calendar Events  
- **Promotional Text:** Transform any text into organized calendar events with AI. Free with ads, Premium for unlimited ad-free conversions.

### 3.2 App Description
```
Transform any text into perfectly formatted calendar events instantly with EventAI's advanced AI technology.

🤖 INTELLIGENT EVENT CREATION
Simply paste any text - emails, messages, meeting notes, or casual conversations - and EventAI will automatically extract dates, times, locations, and create properly formatted calendar events.

⭐ FREE FEATURES
• 3 calendar event conversions per day
• Smart text analysis and event extraction
• Direct calendar integration
• Timezone detection and conversion

💎 PREMIUM FEATURES ($4.99/month)
• Up to 20 calendar event conversions per day
• Ad-free experience for distraction-free productivity
• Photo uploads for additional event context
• Priority processing for faster results

🎯 PERFECT FOR:
• Busy professionals managing multiple meetings
• Event planners organizing complex schedules
• Students tracking assignments and deadlines
• Anyone who receives event information via text

🔒 PRIVACY FOCUSED
Your text is processed securely and never stored. EventAI respects your privacy while delivering powerful AI-driven calendar management.

Download EventAI today and never miss another important event!

Terms of Service: [Your URL]
Privacy Policy: [Your URL]
```

### 3.3 Keywords
Optimize for App Store search:
```
calendar, events, AI, productivity, scheduling, meetings, appointments, text parsing, smart calendar, event creation, time management, agenda, planner, assistant, automation
```

### 3.4 Screenshots Requirements

**iPhone Screenshots (Required for iPhone 6.7" Display):**
1. **Main screen** - Text input interface
2. **Event preview** - Generated events with Premium banner ads
3. **Premium comparison** - Free vs Premium features
4. **Photo upload** - Premium feature demonstration  
5. **Calendar integration** - Events being added to calendar

**App Store Screenshot Text Overlays:**
- "Transform Any Text Into Calendar Events"
- "Free: 3 Events/Day • Premium: 20 Events/Day"
- "Add Photos for Context (Premium)"
- "Ad-Free Premium Experience"
- "Smart AI-Powered Event Detection"

---

## 🧪 Step 4: Sandbox Testing Configuration

### 4.1 Create Sandbox Testers
1. Navigate to **Users and Access** → **Sandbox Testers**
2. Click **"+"** to add testers
3. Create test accounts with different App Store regions:
   - **US Account:** test-us@yourdomain.com
   - **EU Account:** test-eu@yourdomain.com

### 4.2 Test Subscription Flows
**Critical Testing Scenarios:**
- ✅ Purchase monthly subscription
- ✅ Cancel subscription (should continue until end of period)
- ✅ Resubscribe after cancellation
- ✅ Family sharing functionality
- ✅ Price changes handling
- ✅ Restore purchases on new device

### 4.3 Accelerated Testing
Enable **"Sandbox Environment"** settings:
- 1 week subscription = 3 minutes in sandbox
- 1 month subscription = 5 minutes in sandbox
- Perfect for testing renewal flows quickly

---

## 📊 Step 5: App Analytics & Server Notifications

### 5.1 App Store Server Notifications
Configure webhooks to receive real-time subscription updates:

1. Navigate to **App Information** → **App Store Server Notifications**
2. Add your backend webhook URL:
   ```
   https://leveluplife-api-661796696046.us-central1.run.app/webhooks/app-store
   ```
3. Choose notification types:
   - `SUBSCRIBED` - New subscription
   - `DID_RENEW` - Successful renewal
   - `EXPIRED` - Subscription expired
   - `DID_CHANGE_RENEWAL_STATUS` - Auto-renewal status changed

### 5.2 Receipt Validation Setup
Your backend should validate receipts using:
- **Production URL:** `https://buy.itunes.apple.com/verifyReceipt`
- **Sandbox URL:** `https://sandbox.itunes.apple.com/verifyReceipt`

---

## 🚀 Step 6: App Review Preparation

### 6.1 Review Notes for Apple
Provide clear instructions for Apple reviewers:

```
REVIEWER INSTRUCTIONS FOR EVENTAI FREEMIUM MODEL:

1. FREE TIER TESTING:
   - Launch app and enter any text with dates/times
   - App will show full-screen ad for 5 seconds before proceeding
   - After 3 conversions, app will prompt for Premium upgrade
   - Banner ads appear in event preview every 3 events

2. PREMIUM TIER TESTING:
   - Use provided test account: [sandbox-test@yourdomain.com] / [password]
   - Subscription removes all ads immediately
   - Increases daily limit to 20 conversions
   - Enables photo upload feature in text input

3. KEY FEATURES TO VERIFY:
   - Text-to-calendar conversion works accurately
   - Usage limits enforced properly
   - Subscription purchase flow completes
   - Photo upload restricted to Premium users

4. TEST DATA:
   Sample text: "Meeting with John tomorrow at 2 PM at Starbucks on 5th Avenue"
   Expected: Creates calendar event with extracted details
```

### 6.2 Age Rating Configuration
Configure **Age Rating** questionnaire:
- **Frequent/Intense Cartoon or Fantasy Violence:** No
- **Frequent/Intense Realistic Violence:** No
- **Frequent/Intense Sexual Content or Nudity:** No
- **Frequent/Intense Profanity or Crude Humor:** No
- **Frequent/Intense Alcohol, Tobacco, or Drug Use:** No
- **Frequent/Intense Mature/Suggestive Themes:** No
- **Frequent/Intense Horror/Fear Themes:** No
- **Frequent/Intense Medical/Treatment Information:** No

**Result:** Age 4+ (suitable for all ages)

---

## 💡 Step 7: Marketing & Monetization Strategy

### 7.1 App Store Optimization (ASO)
**Target Keywords:**
- Primary: "calendar app", "AI calendar", "event creator"
- Long-tail: "text to calendar events", "smart scheduling app"

### 7.2 Conversion Rate Optimization
**Free-to-Premium Conversion Strategies:**
- Strategic ad placement at optimal moments
- Clear value proposition in upgrade prompts
- Limited free usage creates natural upgrade pressure
- Photo feature as premium differentiator

### 7.3 Retention Strategies
- **Onboarding:** Guide users through first conversion
- **Habit Formation:** Encourage daily usage within free limits
- **Value Demonstration:** Show time saved with AI conversion

---

## 🔍 Step 8: Launch Checklist

### Pre-Launch Verification:
- [ ] App builds and runs without crashes
- [ ] StoreKit integration tested in sandbox
- [ ] Usage limits properly enforced
- [ ] Ads display correctly for free users
- [ ] Photo upload restricted to premium
- [ ] Backend API handles subscription validation
- [ ] Privacy Policy and Terms of Service URLs active
- [ ] All screenshots and metadata reviewed
- [ ] Age rating appropriate and submitted
- [ ] Subscription pricing confirmed in all markets

### Post-Launch Monitoring:
- [ ] Track conversion rates from free to premium
- [ ] Monitor subscription renewal rates
- [ ] Analyze user behavior with usage limits
- [ ] Collect feedback on premium features
- [ ] Monitor App Store reviews and ratings

---

## 📞 Support & Resources

### Apple Documentation:
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Subscription Best Practices](https://developer.apple.com/app-store/subscriptions/)

### EventAI Technical Support:
- Backend API: Level Up Life production environment
- iOS Codebase: `/Users/mfiume/Development/EventAI/EventAI-ios/`
- Product ID Reference: `eventai_premium_monthly`

---

## 🎉 Success Metrics

**Key Performance Indicators:**
- **Free-to-Premium Conversion Rate:** Target 2-5%
- **Monthly Churn Rate:** Target <5%
- **Average Revenue Per User (ARPU):** $4.99 × retention rate
- **Daily Active Users:** Monitor free tier engagement
- **Feature Adoption:** Photo upload usage among premium users

**Revenue Projections:**
- 1,000 DAU × 3% conversion × $4.99 = ~$150/month
- 10,000 DAU × 3% conversion × $4.99 = ~$1,500/month
- 100,000 DAU × 3% conversion × $4.99 = ~$15,000/month

---

**🚀 Your EventAI freemium model is now ready for App Store Connect configuration!**

*This guide covers all necessary steps to successfully launch EventAI with a profitable subscription-based freemium model.*