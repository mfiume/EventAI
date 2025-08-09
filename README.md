# EventAI

EventAI is an iOS app that converts natural language text into calendar events using AI. Simply describe your event in plain English, and EventAI will create a calendar entry that you can import directly into your iOS calendar.

## Features

- 🤖 **AI-Powered**: Uses Claude AI to intelligently parse natural language
- 📱 **Native iOS**: Built with SwiftUI for a smooth user experience  
- 📅 **Direct Calendar Integration**: Adds events directly to your iOS calendar
- 💰 **Ad-Supported**: Free to use with unobtrusive banner advertisements
- ⚡ **Fast & Reliable**: Hosted on Google Cloud Run for high availability

## Architecture

- **iOS App**: Native Swift/SwiftUI app with EventKit integration
- **Backend**: Python FastAPI service with Claude AI integration
- **Deployment**: Google Cloud Run with custom domain routing
- **Monetization**: Google AdMob banner advertisements

## Getting Started

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd calendar-backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up secrets:
   ```bash
   cp secrets/secrets.example.env secrets/secrets.env
   # Edit secrets/secrets.env with your Anthropic API key
   ```

4. Deploy to Google Cloud Run:
   ```bash
   ./deploy.sh
   ```

### iOS App Setup

1. Navigate to the iOS directory:
   ```bash
   cd EventAI-ios
   ```

2. Set up secrets:
   ```bash
   ./setup_config.sh
   # This will create secrets/Config.xcconfig from the template
   # Edit secrets/Config.xcconfig with your AdMob IDs if needed
   ```

3. Configure Xcode project:
   - Open EventAI.xcodeproj in Xcode
   - Go to Project Settings → Build Settings  
   - Set "Based on Configuration File" to `secrets/Config.xcconfig`

4. Open in Xcode:
   ```bash
   open EventAI.xcodeproj
   ```

5. Build and run on your device or simulator

**The app is now configured to use the production EventAI API at `https://eventai.leveluplife.app/api/`**

## Usage Examples

EventAI can parse various types of natural language input:

- "Dentist appointment tomorrow at 2pm"
- "Team meeting next Monday from 9 to 10 AM in Conference Room B"
- "Birthday party this Saturday at 6pm at John's house"
- "Call mom every Sunday at 3pm"

## Configuration

### Environment Variables (Backend)

- `ANTHROPIC_API_KEY`: Your Claude API key from Anthropic
- `PORT`: Server port (default: 8080)
- `NODE_ENV`: Environment (production/development)

### iOS Configuration

Edit `secrets/Config.xcconfig` with:
- `API_BASE_URL`: Set to `https://eventai.leveluplife.app/api` (already configured)
- `ADMOB_APP_ID`: Your Google AdMob App ID  
- `BANNER_AD_UNIT_ID`: Your AdMob Banner Ad Unit ID

## Security

- **No API keys in source code**: All keys stored in gitignored `secrets/` directories
- **Secure random key generation**: Use `openssl rand -hex 32` for secrets
- **Calendar permissions**: Requests proper iOS calendar access permissions

## Current Status

✅ **Backend**: Deployed and running on Google Cloud Run  
✅ **Load Balancer**: Professional Google Cloud Load Balancer with SSL  
✅ **Domain**: https://eventai.leveluplife.app fully operational  
✅ **iOS App**: Configured to use production API at https://eventai.leveluplife.app/api  

## Live URLs

- **Production API**: https://eventai.leveluplife.app/api ✅ **LIVE**
- **Health Check**: https://eventai.leveluplife.app/api/health ✅ **LIVE**
- **API Docs**: https://eventai.leveluplife.app/docs ✅ **LIVE**

## License

This project is proprietary software. All rights reserved.

## Contact

For questions or support, contact: [your-email@domain.com]