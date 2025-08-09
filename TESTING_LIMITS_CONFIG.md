# EventAI Testing Configuration

## 🧪 Current Testing Configuration (TEMPORARY)

The EventAI backend has been temporarily configured with increased daily limits for testing purposes.

### **Current Testing Limits:**
- **Free Users**: 100 conversions/day (was 3)
- **Premium Users**: 200 conversions/day (was 20)

### **Timezone-Based Reset Configuration:**
- **Reset Timezone**: America/New_York (Eastern Time)
- **Reset Time**: 12:00 AM ET (midnight)
- **Reset Logic**: Absolute time-based, not rolling 24-hour periods

## 📋 Changes Made

### 1. Backend Configuration (`calendar-backend/main.py`)

```python
# Usage limits (temporarily increased for testing - change back for production)
FREE_DAILY_LIMIT = 100  # TODO: Change back to 3 for production
PREMIUM_DAILY_LIMIT = 200  # TODO: Change back to 20 for production

# Reset configuration
RESET_TIMEZONE = "America/New_York"  # Eastern Time
RESET_HOUR = 0  # Midnight (24-hour format)
```

### 2. Enhanced Usage Tracking

**New API Response Fields:**
```json
{
  "count": 0,
  "limit": 100,
  "remaining": 100,
  "is_premium": false,
  "reset_date": "2025-08-09",
  "can_convert": true,
  "reset_time": "2025-08-10T00:00:00-04:00",
  "reset_timezone": "America/New_York"
}
```

### 3. Backend Service

**Deployed to correct service:**
- Service name: `eventai-api` (NOT event-ai-api)
- Direct URL: `https://eventai-api-661796696046.us-central1.run.app/api`
- Custom domain: `https://eventai.leveluplife.app/api`

## 🔄 How to Revert for Production

### 1. Backend Limits (`calendar-backend/main.py`)

```python
# Change these lines back to production values:
FREE_DAILY_LIMIT = 3        # Change from 100 to 3
PREMIUM_DAILY_LIMIT = 20    # Change from 200 to 20
```

### 2. iOS App URL (`EventAI/Services/APIService.swift`)

```swift
// Change back to custom domain:
self.baseURL = "https://eventai.leveluplife.app/api"
```

### 3. Deploy Changes

```bash
# 1. Update backend
cd calendar-backend
./deploy.sh

# 2. Update domain mapping (if needed)
gcloud run services update-traffic event-ai-api --to-latest

# 3. Rebuild and deploy iOS app
cd ../EventAI-ios
# Build and deploy through Xcode or CI/CD
```

## 🎯 Testing Benefits

### **For Development:**
- **More testing iterations**: 100/200 daily limits allow extensive testing
- **Realistic usage patterns**: Test high-volume scenarios
- **Timezone accuracy**: Predictable midnight ET resets

### **For Users:**
- **Consistent reset times**: All users reset at midnight ET
- **Transparent scheduling**: Apps can show "Resets at 12:00 AM ET"
- **Fair usage windows**: 24-hour periods are calendar days, not rolling

## ⚠️ Production Checklist

Before going to production:

- [ ] Update `FREE_DAILY_LIMIT` back to 3
- [ ] Update `PREMIUM_DAILY_LIMIT` back to 20  
- [ ] Update iOS app to use custom domain
- [ ] Deploy updated backend
- [ ] Test with production limits
- [ ] Update App Store listing if needed
- [ ] Monitor usage analytics

## 📊 Current Status

- ✅ Backend deployed with increased limits
- ✅ Timezone-based reset implemented (midnight ET)
- ✅ iOS app connected to updated backend
- ✅ Usage tracking shows real-time data
- ✅ Premium modal opens when limits reached

**Ready for extensive testing with 100/200 daily conversion limits!**