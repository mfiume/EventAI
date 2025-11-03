# EventAI - AI-Powered Calendar Event Creation

Convert natural language and images into calendar events using AI.

**Version 2.0** - Now with client-side AI integration (no backend required!)

## 🎉 What's New in Version 2.0

- ✅ **Unlimited Conversions** - No more daily limits
- ✅ **70-99% Cost Reduction** - Pay only for AI usage (~$0.001 per conversion)
- ✅ **Enhanced Privacy** - Zero data collection, no tracking
- ✅ **Your Choice of AI** - Use Anthropic Claude OR OpenAI GPT
- ✅ **No Subscription** - Free app, bring your own API key
- ✅ **Faster Processing** - Direct API calls to AI providers

## Features

- 🤖 **AI-Powered**: Uses Anthropic Claude or OpenAI GPT for intelligent parsing
- 📱 **Native iOS**: Built with SwiftUI for smooth user experience
- 🌐 **Web App**: Responsive web interface with ICS file download
- 📅 **Direct Calendar Integration**: Adds events directly to iOS calendar
- 📸 **Vision Support**: Extract events from images and screenshots
- 🔒 **Privacy-Focused**: No backend, no tracking, no data collection
- 💰 **Cost-Effective**: Most users spend less than $1/month on AI API costs

## Architecture

### EventAI 2.0 (Current)
- **iOS App**: Native Swift/SwiftUI with direct AI API integration
- **Web App**: Vanilla JavaScript with client-side ICS generation
- **No Backend**: All AI calls go directly from client to Anthropic/OpenAI
- **No Database**: No user data storage or tracking
- **Secure Storage**: iOS Keychain (iOS) / localStorage (Web)

## Getting Started

### iOS App

1. Download EventAI from the App Store
2. Open the app and tap the Settings gear icon
3. Choose your AI provider (Anthropic or OpenAI)
4. Enter your API key
5. Tap "Test Connection" to verify
6. Start creating calendar events!

### Web App

1. Visit https://eventai.leveluplife.app
2. Click the Settings gear icon
3. Select your AI provider
4. Enter your API key
5. Test the connection
6. Convert text to calendar events and download ICS files

### Getting API Keys

**Anthropic Claude (Recommended)**
1. Visit https://console.anthropic.com
2. Sign up for a free account
3. Navigate to API Keys section
4. Generate a new API key
5. Copy and paste into EventAI Settings

**OpenAI**
1. Visit https://platform.openai.com
2. Sign up for an account
3. Navigate to API Keys section
4. Generate a new secret key
5. Copy and paste into EventAI Settings

## Usage Examples

### Simple Event
**Input**: "Dentist appointment on Friday at 2pm"
**Output**: Single calendar event on next Friday at 2:00 PM

### Recurring Event
**Input**: "Yoga class every Tuesday and Thursday at 6:30am"
**Output**: Recurring event (every Tuesday and Thursday)

### All-Day Event
**Input**: "John's birthday on March 15th"
**Output**: All-day calendar event on March 15th

### Complex Schedule
**Input**: Screenshot of a weekly class schedule
**Output**: Multiple calendar events with proper times and locations

## Cost Comparison

### Old Model (EventAI 1.x)
- Free: 2 conversions/day (limited)
- Premium: $0.99/month for 20 conversions/day

### New Model (EventAI 2.0)
- **Unlimited conversions**
- Pay only for AI API usage
- Example: 300 conversions/month = **$0.06-0.30/month**
- **Savings: 70-99%**

Most users spend **less than $1/month** on AI API costs.

## Privacy & Security

EventAI 2.0 is built with privacy as a core principle:

- ✅ **No Backend Server** - All AI calls go directly to the AI provider
- ✅ **No Data Collection** - We don't collect, store, or analyze any data
- ✅ **No Tracking** - No analytics, no device fingerprinting
- ✅ **Secure Storage**: iOS Keychain (iOS) / localStorage (Web)
- ✅ **Open Source** - Full transparency into how the app works

Your API key is stored **only on your device** and never sent to EventAI servers.

## Technical Details

### iOS App
- **Technology**: Swift, SwiftUI, EventKit
- **Minimum iOS Version**: iOS 15.0+
- **Storage**: iOS Keychain for API keys

### Web App
- **Technology**: Vanilla JavaScript, HTML5, CSS3
- **Hosting**: Static hosting (Netlify/Vercel/GitHub Pages)
- **Storage**: localStorage for configuration

## Documentation

- **Refactoring Plan**: See [REFACTORING_PLAN.md](./REFACTORING_PLAN.md) for detailed refactoring documentation
- **Implementation Summary**: See [REFACTORING_COMPLETE.md](./REFACTORING_COMPLETE.md) for complete implementation details
- **Migration Guide**: See [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) for upgrading from v1.x

## Development

### Project Structure
```
EventAI/
├── EventAI-ios/                # iOS app source
│   ├── EventAI/
│   │   ├── Views/             # SwiftUI views
│   │   ├── Services/          # API and calendar services
│   │   └── Models/            # Data models
│   └── Config.xcconfig        # Configuration (gitignored)
│
├── eventai-web/               # Web app
│   ├── index.html
│   ├── script.js
│   └── style.css
│
└── calendar-backend/          # Legacy backend (v1.x, deprecated)
```

### Building iOS App
```bash
# Open in Xcode
open EventAI-ios/EventAI.xcodeproj

# Build for simulator
xcodebuild -scheme EventAI \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Web App Locally
```bash
cd eventai-web
python3 -m http.server 8080
open http://localhost:8080
```

## Support

- 📧 Email: support@leveluplife.app
- 🐛 Bug Reports: GitHub Issues
- 📖 Documentation: https://docs.leveluplife.app/eventai

## License

MIT License - see [LICENSE](./LICENSE) for details

## Changelog

### Version 2.0.0 (November 2025)
- ✨ Added client-side AI integration (Anthropic + OpenAI)
- ✨ Added Settings UI for API key configuration
- ✨ Added iOS Keychain storage for API keys
- 🗑️ Removed backend dependency
- 🗑️ Removed usage tracking and limits
- 🗑️ Removed subscription system
- 🗑️ Removed AdMob ads
- ⚡ Improved conversion speed
- 🔒 Enhanced privacy (zero data collection)
- 💰 Reduced costs for users (70-99% savings)

### Version 1.x (Legacy)
- Initial release with hosted backend
- Freemium model with subscriptions

---

**Made with ❤️ by the EventAI Team**

Visit us at https://leveluplife.app/eventai