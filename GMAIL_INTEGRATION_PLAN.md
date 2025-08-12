# EventAI Gmail Integration Plan

## 🎯 Vision
Create a Gmail Add-on that allows users to extract calendar events from emails with one click, using EventAI's AI processing, and add them directly to their Google Calendar.

## 🏗️ Architecture Overview

### Components
1. **Gmail Add-on** (Frontend) - Google Apps Script + HTML/JS
2. **EventAI Gmail API** (Backend) - New endpoints in FastAPI
3. **Google OAuth Integration** - Authentication and Calendar access
4. **Event Preview Interface** - Similar to iOS app

### User Flow
1. User opens email in Gmail
2. Clicks "Extract Events" button in sidebar
3. Email content sent to EventAI API
4. AI processes and returns events
5. User previews and selects events
6. Events added to chosen Google Calendar

## 🔐 Authentication Strategy

### Google OAuth 2.0 Flow
- **Scopes needed:**
  - `https://www.googleapis.com/auth/gmail.readonly` - Read email content
  - `https://www.googleapis.com/auth/calendar` - Manage Google Calendar
  - `https://www.googleapis.com/auth/userinfo.email` - User identification

### EventAI API Authentication
- Generate Google-specific API keys
- Link Google accounts to EventAI usage tracking
- Implement rate limiting per Google user

## 📱 Technical Implementation

### 1. Gmail Add-on (Google Apps Script)
- **Card-based UI** for Gmail sidebar
- **Event extraction** button
- **Preview interface** matching iOS app design
- **Calendar selection** dropdown

### 2. Backend API Extensions
- **New endpoints:**
  - `POST /api/gmail/extract` - Process email content
  - `GET /api/gmail/calendars` - List user's calendars
  - `POST /api/gmail/events` - Add events to calendar
- **Google OAuth integration**
- **Usage tracking** for Gmail users

### 3. Google Calendar Integration
- **Calendar listing** from user's account
- **Event creation** with proper formatting
- **Conflict detection** and warnings

## 🚀 Development Phases

### Phase 1: Backend API (1-2 days)
- Extend EventAI backend with Gmail endpoints
- Implement Google OAuth authentication
- Add Google Calendar API integration
- Test with Postman/curl

### Phase 2: Gmail Add-on (2-3 days)
- Create Google Apps Script project
- Build Gmail sidebar interface
- Implement event preview UI
- Connect to EventAI backend

### Phase 3: Integration & Testing (1 day)
- End-to-end testing with real Gmail accounts
- Performance optimization
- Error handling and edge cases

### Phase 4: Deployment (1 day)
- Deploy backend changes
- Publish Gmail Add-on for testing
- Documentation and user guides

## 💰 Monetization Integration
- **Free tier:** 3 email extractions per day
- **Premium tier:** Unlimited extractions + priority processing
- **Seamless upsell** within Gmail interface

## 🛡️ Security & Privacy
- **Minimal data retention** - process and discard email content
- **Secure OAuth flow** with proper token management
- **Rate limiting** to prevent abuse
- **Privacy-first design** - no email storage

## 📊 Success Metrics
- **Adoption rate** - Gmail Add-on installs
- **Usage frequency** - Events extracted per user
- **Conversion rate** - Free to premium upgrades
- **User satisfaction** - Event extraction accuracy

---

**Target Launch:** 5-7 days from start
**Primary Benefits:** 
- Massive market expansion (Gmail has 1.8B users)
- Natural workflow integration
- Premium subscription driver
- Competitive differentiation