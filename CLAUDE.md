# EventAI - Project Instructions for Claude Code

## 🚀 Project Overview

**EventAI** is an iOS app that converts natural language text into calendar events using AI. It features a freemium model with usage limits and subscription management.

### **Technology Stack**
- **Frontend**: Native iOS Swift app with SwiftUI
- **Backend**: Python FastAPI deployed on Google Cloud Run
- **AI**: Anthropic Claude API for text-to-calendar conversion
- **Monetization**: StoreKit 2 subscriptions + AdMob interstitial ads
- **Authentication**: Device-based user identification

---

## 🏗️ Project Structure

```
EventAI/
├── EventAI-ios/                    # Native iOS Swift App
│   ├── EventAI/
│   │   ├── EventAIApp.swift           # App entry point
│   │   ├── ContentView.swift          # Main UI with freemium logic
│   │   ├── Services/                  # API client & services
│   │   │   ├── APIService.swift       # Backend API calls
│   │   │   ├── AdService.swift        # AdMob integration
│   │   │   ├── CalendarService.swift  # iOS Calendar access
│   │   │   ├── LocationService.swift  # Timezone inference
│   │   │   └── SubscriptionService.swift # StoreKit 2 premium
│   │   └── Views/                     # SwiftUI components
│   │       ├── PremiumModalView.swift # Upgrade modal
│   │       └── TimezonePickerView.swift
│   ├── EventAI.xcodeproj/
│   └── secrets/                       # API keys (gitignored)
│
├── calendar-backend/               # Python FastAPI Backend
│   ├── main.py                       # FastAPI server with usage tracking
│   ├── deploy.sh                     # Google Cloud Run deployment
│   ├── Dockerfile                    # Container configuration
│   ├── requirements.txt              # Python dependencies
│   └── secrets/                      # Environment variables (gitignored)
│
└── TESTING_LIMITS_CONFIG.md       # Testing vs production config
```

---

## 🔧 Critical Configuration

### **Backend Deployment (IMPORTANT)**
- **Service Name**: `eventai-api` (NOT event-ai-api!)
- **Domain**: `https://eventai.leveluplife.app/api`
- **Google Cloud Project**: `levelup-467902`
- **Region**: `us-central1`

### **Deploy Command**
```bash
cd calendar-backend
./deploy.sh  # Deploys to eventai-api service
```

### **API Endpoints**
- **Health**: `https://eventai.leveluplife.app/api/health`
- **Usage Stats**: `https://eventai.leveluplife.app/api/usage`
- **Convert Text**: `https://eventai.leveluplife.app/api/convert`

### **Usage Limits**
```python
# Production limits
FREE_DAILY_LIMIT = 3
PREMIUM_DAILY_LIMIT = 20

# Reset configuration
RESET_TIMEZONE = "America/New_York"
RESET_HOUR = 0  # Midnight ET
```

---

## 🚨 Critical Rules

### **NEVER DO:**
❌ Deploy to `event-ai-api` (wrong service name!)
❌ Hardcode API keys in source files
❌ Commit real secrets (Config.xcconfig, secrets.env files)
❌ Use mock data or fallback implementations
❌ Auto-commit changes without explicit user instruction

### **ALWAYS DO:**
✅ Deploy to `eventai-api` service name
✅ Use custom domain `https://eventai.leveluplife.app/api`
✅ Generate secure keys using `openssl rand -hex 32`
✅ Keep secrets gitignored
✅ Test with real API data
✅ Wait for explicit commit instructions

---

## 📱 iOS App Configuration

### **API Base URL**
```swift
// APIService.swift
self.baseURL = "https://eventai.leveluplife.app/api"
```

### **Freemium Features**
- **Free**: 3 daily conversions + interstitial ads
- **Premium**: 20 daily conversions + no ads + photo analysis
- **Subscription**: $4.99/month via StoreKit 2

### **Usage Tracking Flow**
1. App calls `/usage` to get current limits
2. Shows "X of Y remaining" in UI
3. Blocks conversions when limit reached
4. Opens premium modal instead of alerts

---

## 🔄 Development vs Production

### **Testing Configuration**
For testing, temporarily increase limits in `main.py`:
```python
FREE_DAILY_LIMIT = 100   # Testing only
PREMIUM_DAILY_LIMIT = 200 # Testing only
```

### **Production Configuration**
```python
FREE_DAILY_LIMIT = 3     # Production
PREMIUM_DAILY_LIMIT = 20  # Production
```

---

## 🛠️ Development Commands

### **Backend Development**
```bash
cd calendar-backend

# Deploy to Google Cloud Run
./deploy.sh

# Test deployment
curl https://eventai.leveluplife.app/api/health
```

### **iOS Development**
```bash
cd EventAI-ios

# Build for simulator
xcodebuild -project EventAI.xcodeproj -scheme EventAI -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 16'

# Install to simulator
xcrun simctl install "iPhone 16" /path/to/EventAI.app
```

---

## ⚠️ Emergency Procedures

### **Wrong Service Deployment**
If accidentally deployed to `event-ai-api`:
1. Fix `deploy.sh`: Change `SERVICE_NAME="eventai-api"`
2. Redeploy to correct service
3. Update domain mapping if needed

### **API Key Issues**
1. Generate new key: `openssl rand -hex 32`
2. Update `secrets/secrets.env`
3. Redeploy backend
4. Test all endpoints

---

## 🎯 Current Status

✅ **Backend**: Deployed to `eventai-api` service
✅ **iOS App**: Native Swift with freemium model
✅ **Usage Tracking**: Real-time with timezone-based resets
✅ **Monetization**: StoreKit 2 + AdMob integration
✅ **Security**: API keys properly secured

---

**🎯 Remember: Always deploy to `eventai-api`, never `event-ai-api`!**